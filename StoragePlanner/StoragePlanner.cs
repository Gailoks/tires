using Microsoft.Extensions.Logging;
using Tires.Primitives;
using Tires.Config;
namespace Tires.Storage;

public class StoragePlanner : IStoragePlanner
{
	private readonly ILogger<StoragePlanner> _logger;
	private List<Tier> _tiers;
	private List<FolderPlan> _folderPlans;
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

		// Step 1: Separate excluded files (IgnoreRule) from movable files
		var (excludedFiles, movableFiles) = SeparateExcludedFiles(files);

		_logger.LogInformation("Files: {Total} total, {Excluded} excluded, {Movable} movable",
			files.Count, excludedFiles.Count, movableFiles.Count);

		// Step 2: Sort movable files by rules
		var sortedMovable = ApplySortingRules(movableFiles);

		// Step 3: Calculate distribution boundaries based on available space
		// This also reorganizes files so each tier gets consecutive ranges
		var (reorganizedFiles, boundaries) = CalculateBoundaries(sortedMovable);

		_logger.LogInformation("File distribution completed");
		return (reorganizedFiles, boundaries);
	}

	private (List<FileEntry> Excluded, List<FileEntry> Movable) SeparateExcludedFiles(List<FileEntry> files)
	{
		var excluded = new List<FileEntry>();
		var movable = new List<FileEntry>();

		if (_folderPlans.Count == 0)
			return (excluded, files);

		var excludedIndices = new HashSet<int>();

		// Find all files that match IgnoreRule (exclusion rules)
		foreach (var plan in _folderPlans.OrderByDescending(p => p.Priority))
		{
			// Check if this is an IgnoreRule (exclusion rule)
			if (plan.Rule.GetType().Name == "IgnoreRule")
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

		// All non-excluded files are movable
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
			return files.OrderBy(f => f.Size).ToList();

		var result = new List<FileEntry>();
		var matchedIndices = new HashSet<int>();

		// Process each folder rule in priority order (only non-IgnoreRule)
		foreach (var plan in _folderPlans.OrderByDescending(p => p.Priority))
		{
			// Skip IgnoreRule for sorting (it's only for exclusion)
			if (plan.Rule.GetType().Name == "IgnoreRule")
				continue;

			var matched = files
				.Select((f, i) => (File: f, Index: i, Score: CalculateScore(plan, f)))
				.Where(x => !matchedIndices.Contains(x.Index) && MatchesFolder(plan, x.File))
				.OrderBy(x => x.Score)
				.ToList();

			foreach (var m in matched)
			{
				result.Add(m.File);
				matchedIndices.Add(m.Index);
			}
		}

		// Add remaining files with default rule (size ascending)
		var unmatched = files
			.Select((f, i) => (File: f, Index: i))
			.Where(x => !matchedIndices.Contains(x.Index))
			.OrderBy(x => x.File.Size)
			.Select(x => x.File)
			.ToList();

		result.AddRange(unmatched);
		return result;
	}

	private (List<FileEntry> ReorganizedFiles, List<int> Boundaries) CalculateBoundaries(List<FileEntry> sortedFiles)
	{
		List<int> boundaries = new();
		var assignedIndices = new HashSet<int>();
		var tierFiles = new List<List<FileEntry>>();

		_logger.LogDebug("Calculating boundaries for {TierCount} tiers with {FileCount} movable files",
			_tiers.Count, sortedFiles.Count);

		// For each tier (except last), calculate which files fit based on priority order
		for (int a = 0; a < _tiers.Count - 1; a++)
		{
			var tier = _tiers[a];
			long allowedBytes = Math.Max(0, tier.Free);
			var tierFileList = new List<FileEntry>();

			_logger.LogDebug("Tier {TierIndex}: capacity={Capacity}, target={Target}%, free={Free}, allowed={Allowed}",
				a, tier.Capacity, tier.Target, tier.Free, allowedBytes);

			long cumulative = 0;

			// Try to fit files in priority order (greedy bin-packing)
			// Continue through ALL files, not just consecutive ones
			for (int i = 0; i < sortedFiles.Count; i++)
			{
				if (assignedIndices.Contains(i))
					continue;

				if (cumulative + sortedFiles[i].Size <= allowedBytes)
				{
					cumulative += sortedFiles[i].Size;
					assignedIndices.Add(i);
					tierFileList.Add(sortedFiles[i]);
				}
			}

			tierFiles.Add(tierFileList);
			_logger.LogDebug("Tier {TierIndex}: assigned {Count} files ({Bytes} bytes)",
				a, tierFileList.Count, cumulative);
		}

		// Last tier gets all remaining files (overflow)
		var lastTierFiles = new List<FileEntry>();
		for (int i = 0; i < sortedFiles.Count; i++)
		{
			if (!assignedIndices.Contains(i))
				lastTierFiles.Add(sortedFiles[i]);
		}
		tierFiles.Add(lastTierFiles);

		_logger.LogDebug("Tier {TierIndex} (last): assigned {Count} files",
			_tiers.Count - 1, lastTierFiles.Count);

		// Reorganize files: concatenate all tier files in order
		var reorganizedFiles = new List<FileEntry>();
		int cumulativeCount = 0;
		foreach (var tierFileList in tierFiles)
		{
			reorganizedFiles.AddRange(tierFileList);
			cumulativeCount += tierFileList.Count;
			// Boundary is the index of the last file for this tier
			boundaries.Add(cumulativeCount - 1);
		}

		return (reorganizedFiles, boundaries);
	}

	private bool MatchesFolder(FolderPlan plan, FileEntry file)
	{
		foreach (var path in file.Paths)
		{
			// Check if the path contains the folder prefix
			// This works for both absolute and relative paths
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