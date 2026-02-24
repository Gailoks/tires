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

		var sortedMovable = ApplySortingRules(movableFiles);
		var (reorganizedFiles, boundaries) = CalculateBoundaries(sortedMovable);

		_logger.LogInformation("File distribution completed");
		return (reorganizedFiles, boundaries);
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

		var result = new List<FileEntry>(files.Count);
		var matchedIndices = new HashSet<int>();

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
					result.Add(files[i]);
					matchedIndices.Add(i);
				}
			}
		}

		result.Sort((a, b) => a.Size.CompareTo(b.Size));

		var unmatched = new List<FileEntry>();
		for (int i = 0; i < files.Count; i++)
		{
			if (!matchedIndices.Contains(i))
				unmatched.Add(files[i]);
		}
		unmatched.Sort((a, b) => a.Size.CompareTo(b.Size));

		result.InsertRange(result.Count, unmatched);
		return result;
	}

	private (List<FileEntry> ReorganizedFiles, List<int> Boundaries) CalculateBoundaries(List<FileEntry> sortedFiles)
	{
		var boundaries = new List<int>(_tiers.Count);
		var assignedIndices = new HashSet<int>();
		var tierFiles = new List<List<FileEntry>>(_tiers.Count);

		_logger.LogDebug("Calculating boundaries for {TierCount} tiers with {FileCount} movable files",
			_tiers.Count, sortedFiles.Count);

		for (int a = 0; a < _tiers.Count - 1; a++)
		{
			var tier = _tiers[a];
			long allowedBytes = Math.Max(0, tier.Free);
			var tierFileList = new List<FileEntry>();

			_logger.LogDebug("Tier {TierIndex}: capacity={Capacity}, target={Target}%, free={Free}, allowed={Allowed}",
				a, tier.Capacity, tier.Target, tier.Free, allowedBytes);

			long cumulative = 0;

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

		var lastTierFiles = new List<FileEntry>();
		for (int i = 0; i < sortedFiles.Count; i++)
		{
			if (!assignedIndices.Contains(i))
				lastTierFiles.Add(sortedFiles[i]);
		}
		tierFiles.Add(lastTierFiles);

		_logger.LogDebug("Tier {TierIndex} (last): assigned {Count} files",
			_tiers.Count - 1, lastTierFiles.Count);

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