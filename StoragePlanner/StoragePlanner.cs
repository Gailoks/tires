using Microsoft.Extensions.Logging;
using Tires.Primitives;
using Tires.Config;
using Tires.Rules;

namespace Tires.Storage;

public class StoragePlanner : IStoragePlanner
{
	private readonly ILogger<StoragePlanner> _logger;
	private readonly List<Tier> _tiers;
	private readonly List<FolderPlan> _folderPlans;
	public long[] Sizes { get; set; }

	public StoragePlanner(ILogger<StoragePlanner> logger, Configuration configuration, List<FolderPlan> folderPlans)
	{
		_logger = logger;
		_tiers = configuration.Tiers
			.Select(tc => new Tier(tc))
			.ToList();
		_folderPlans = folderPlans.OrderByDescending(f => f.Priority).ToList();
		Sizes = new long[_tiers.Count];
	}

	public (List<FileEntry> SortedFiles, List<int> Boundaries) Distribute(List<FileEntry> files)
	{
		_logger.LogInformation("File distribution started");

		var (excludedFiles, movableFiles) = SeparateExcludedFiles(files);

		_logger.LogInformation("Files: {Total} total, {Excluded} excluded, {Movable} movable",
			files.Count, excludedFiles.Count, movableFiles.Count);

		// Recalculate tier.Free based on movable files only (excludes IgnoreRule files)
		RecalculateTierFreeSpace(movableFiles);

		var sortedMovable = ApplySortingRules(movableFiles);
		var (reorganizedFiles, boundaries) = CalculateBoundaries(sortedMovable);

		_logger.LogInformation("File distribution completed");
		return (reorganizedFiles, boundaries);
	}

	private void RecalculateTierFreeSpace(List<FileEntry> movableFiles)
	{
		// Calculate used space per tier from movable files only
		var movableSizes = new long[_tiers.Count];
		foreach (var file in movableFiles)
		{
			if (file.TierIndex >= 0 && file.TierIndex < _tiers.Count)
				movableSizes[file.TierIndex] += file.Size;
		}

		// Update each tier's free space based on movable files
		for (int i = 0; i < _tiers.Count; i++)
		{
			var tier = _tiers[i];
			long usedByMovable = movableSizes[i];
			long recalculatedFree = Math.Max(0, tier.AllowedSpace - usedByMovable);
			
			_logger.LogDebug("Tier {TierIndex}: allowed={Allowed}, usedByMovable={Used}, free={Free}",
				i, tier.AllowedSpace, usedByMovable, recalculatedFree);
			
			tier.Free = recalculatedFree;
		}
	}

	private (List<FileEntry> Excluded, List<FileEntry> Movable) SeparateExcludedFiles(List<FileEntry> files)
	{
		if (_folderPlans.Count == 0)
			return (new List<FileEntry>(), files);

		var excluded = new List<FileEntry>();
		var movable = new List<FileEntry>(files.Count);
		var excludedIndices = new HashSet<int>();

		foreach (var plan in _folderPlans)
		{
			if (plan.Rule is IgnoreRule)
			{
				for (int i = 0; i < files.Count; i++)
				{
					if (excludedIndices.Contains(i))
						continue;

					if (MatchesFolder(plan, files[i]) && plan.Rule.ShouldExclude(files[i]))
					{
						excludedIndices.Add(i);
						excluded.Add(files[i]);
						_logger.LogDebug("File excluded (IgnoreRule): {File}",
							string.Join(", ", files[i].Paths));
					}
				}
			}
		}

		for (int i = 0; i < files.Count; i++)
		{
			if (!excludedIndices.Contains(i))
				movable.Add(files[i]);
		}

		return (excluded, movable);
	}

	private List<FileEntry> ApplySortingRules(List<FileEntry> files)
	{
		if (_folderPlans.Count == 0)
		{
			var sorted = new List<FileEntry>(files);
			sorted.Sort((a, b) => a.Size.CompareTo(b.Size));
			return sorted;
		}

		var matchedIndices = new HashSet<int>();
		var scoredFiles = new List<(FileEntry File, int Priority, int Score)>();

		// Assign scores based on matching rules
		foreach (var plan in _folderPlans)
		{
			if (plan.Rule is IgnoreRule)
				continue;

			for (int i = 0; i < files.Count; i++)
			{
				if (matchedIndices.Contains(i))
					continue;

				if (MatchesFolder(plan, files[i]))
				{
					int score = CalculateScore(plan, files[i]);
					scoredFiles.Add((files[i], plan.Priority, score));
					matchedIndices.Add(i);
				}
			}
		}

		// Sort by: priority DESC, then score DESC (higher priority + higher score = hotter tier)
		var matched = scoredFiles
			.OrderByDescending(x => x.Priority)
			.ThenByDescending(x => x.Score)
			.Select(x => x.File)
			.ToList();

		// Add unmatched files (sorted by size ascending - default behavior)
		var unmatched = new List<FileEntry>();
		for (int i = 0; i < files.Count; i++)
		{
			if (!matchedIndices.Contains(i))
				unmatched.Add(files[i]);
		}
		unmatched.Sort((a, b) => a.Size.CompareTo(b.Size));

		matched.AddRange(unmatched);
		return matched;
	}

	private (List<FileEntry> ReorganizedFiles, List<int> Boundaries) CalculateBoundaries(List<FileEntry> sortedFiles)
	{
		var boundaries = new List<int>(_tiers.Count);
		var assignedIndices = new HashSet<int>();
		var tierFiles = new List<List<FileEntry>>(_tiers.Count);

		_logger.LogDebug("Calculating boundaries for {TierCount} tiers with {FileCount} movable files",
			_tiers.Count, sortedFiles.Count);

		// First pass: account for files already on their correct tiers
		// Files are sorted by priority/score, so earlier files should be on hotter tiers
		var tierUsedSpace = new long[_tiers.Count];
		
		// Calculate current space usage per tier based on file positions in sorted list
		// Files earlier in the list (higher priority/score) belong on hotter tiers
		int fileIndex = 0;
		for (int a = 0; a < _tiers.Count - 1; a++)
		{
			var tier = _tiers[a];
			long allowedBytes = tier.AllowedSpace;
			long cumulative = 0;

			// Count files that "belong" on this tier based on sorted order
			while (fileIndex < sortedFiles.Count && cumulative < allowedBytes)
			{
				cumulative += sortedFiles[fileIndex].Size;
				fileIndex++;
			}

			tierUsedSpace[a] = cumulative;
			_logger.LogDebug("Tier {TierIndex}: allowed={Allowed}, ideal usage={Ideal}",
				a, allowedBytes, cumulative);
		}

		// Second pass: assign files to tiers, preferring to keep files where they are
		fileIndex = 0;
		for (int a = 0; a < _tiers.Count - 1; a++)
		{
			var tier = _tiers[a];
			long allowedBytes = tier.AllowedSpace;
			var tierFileList = new List<FileEntry>();
			long cumulative = 0;

			_logger.LogDebug("Tier {TierIndex}: capacity={Capacity}, target={Target}%, allowed={Allowed}",
				a, tier.Capacity, tier.Target, allowedBytes);

			// First, keep files already on this tier that fit within capacity
			for (int i = 0; i < sortedFiles.Count; i++)
			{
				if (assignedIndices.Contains(i))
					continue;

				// If file is already on this tier, prefer keeping it
				if (sortedFiles[i].TierIndex == a)
				{
					if (cumulative + sortedFiles[i].Size <= allowedBytes)
					{
						cumulative += sortedFiles[i].Size;
						assignedIndices.Add(i);
						tierFileList.Add(sortedFiles[i]);
						_logger.LogDebug("  Keeping file on tier {Tier}: {File}", a, sortedFiles[i].Paths[0]);
					}
				}
			}

			// Then, fill remaining space with files from other tiers (sorted by priority/score)
			for (int i = 0; i < sortedFiles.Count; i++)
			{
				if (assignedIndices.Contains(i))
					continue;

				if (cumulative + sortedFiles[i].Size <= allowedBytes)
				{
					cumulative += sortedFiles[i].Size;
					assignedIndices.Add(i);
					tierFileList.Add(sortedFiles[i]);
					_logger.LogDebug("  Moving file to tier {Tier}: {File}", a, sortedFiles[i].Paths[0]);
				}
			}

			tierFiles.Add(tierFileList);
			_logger.LogDebug("Tier {TierIndex}: assigned {Count} files ({Bytes} bytes)",
				a, tierFileList.Count, cumulative);
		}

		// Last tier gets all remaining files
		var lastTierFiles = new List<FileEntry>();
		for (int i = 0; i < sortedFiles.Count; i++)
		{
			if (!assignedIndices.Contains(i))
				lastTierFiles.Add(sortedFiles[i]);
		}
		tierFiles.Add(lastTierFiles);

		_logger.LogDebug("Tier {TierIndex} (last): assigned {Count} files",
			_tiers.Count - 1, lastTierFiles.Count);

		// Build final ordered list and boundaries
		var reorganizedFiles = new List<FileEntry>(sortedFiles.Count);
		int cumulativeCount = 0;
		foreach (var tierFileList in tierFiles)
		{
			reorganizedFiles.AddRange(tierFileList);
			cumulativeCount += tierFileList.Count;
			boundaries.Add(cumulativeCount - 1);
		}

		return (reorganizedFiles, boundaries);
	}

	private bool MatchesFolder(FolderPlan plan, FileEntry file)
	{
		foreach (var path in file.Paths)
		{
			if (path.Contains(plan.PathPrefix, StringComparison.OrdinalIgnoreCase))
				return true;
		}
		return false;
	}

	private int CalculateScore(FolderPlan plan, FileEntry file)
	{
		int score = plan.Rule.CalculateScore(file);
		return plan.Reverse ? -score : score;
	}
}