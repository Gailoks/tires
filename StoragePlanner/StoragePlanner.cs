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
		var boundaries = CalculateBoundaries(sortedMovable);

		_logger.LogInformation("File distribution completed");
		return (sortedMovable, boundaries);
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

	private List<int> CalculateBoundaries(List<FileEntry> sortedFiles)
	{
		List<int> indexes = new();
		int currentIndex = 0;

		_logger.LogDebug("Calculating boundaries for {TierCount} tiers with {FileCount} movable files",
			_tiers.Count, sortedFiles.Count);

		// For each tier, calculate how much space is available for new files
		// tier.Free already accounts for target% and used space
		for (int a = 0; a < _tiers.Count; a++)
		{
			var tier = _tiers[a];
			
			// tier.Free is the available space considering target percentage
			// For hot tier (a=0), this is the space we can fill
			// For other tiers, we need to calculate remaining capacity
			long allowedBytes;
			
			if (a == 0)
			{
				// Hot tier: use Free space (already calculated based on target)
				allowedBytes = Math.Max(0, tier.Free);
			}
			else
			{
				// Other tiers: use remaining capacity after hot tier fills up
				// This is a simplified approach - in reality, we'd need to track
				// cumulative space across tiers
				long targetCapacity = (long)(tier.Capacity * tier.Target / 100.0);
				allowedBytes = Math.Max(0, targetCapacity);
			}

			_logger.LogDebug("Tier {TierIndex}: capacity={Capacity}, target={Target}%, free={Free}, allowed={Allowed}",
				a, tier.Capacity, tier.Target, tier.Free, allowedBytes);

			long cumulative = 0;
			int lastIndex = currentIndex - 1;

			for (int i = currentIndex; i < sortedFiles.Count; i++)
			{
				if (cumulative + sortedFiles[i].Size <= allowedBytes)
				{
					cumulative += sortedFiles[i].Size;
					lastIndex = i;
				}
				else
				{
					break;
				}
			}

			indexes.Add(lastIndex);
			currentIndex = lastIndex + 1;

			_logger.LogDebug("Tier {TierIndex}: assigned files {Start} to {End} ({Bytes} bytes)",
				a, a == 0 ? 0 : indexes[a - 1] + 1, lastIndex, cumulative);
		}

		return indexes;
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