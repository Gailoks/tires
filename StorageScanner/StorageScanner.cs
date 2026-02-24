using Tires.Primitives;
using Microsoft.Extensions.Logging;
using Tires.Config;
using System.Buffers;

namespace Tires.Storage;

public class StorageScanner : IStorageScanner
{
	private readonly ILogger<StorageScanner> _logger;
	private readonly List<Tier> _tiers;

	private long[] _sizes;

	public long[] Sizes { get => _sizes; }

	public StorageScanner(ILogger<StorageScanner> logger, Configuration configuration)
	{
		_logger = logger;
		_tiers = configuration.Tiers
			.Select(tc => new Tier(tc))
			.ToList();
		_sizes = new long[configuration.Tiers.Count];
	}

	public List<FileEntry> GetSortedFiles()
	{
		var files = GetAllFilesParallel();
		var sorted = files.OrderBy(f => f.Size).ToList();
		return sorted;
	}

	private List<FileEntry> GetAllFilesParallel()
	{
		_logger.LogInformation("Storage scan started");

		var results = new List<FileEntry>[_tiers.Count];
		var sizeSums = new long[_tiers.Count];

		Parallel.For(0, _tiers.Count, i =>
		{
			var tier = _tiers[i];
			var scanner = new TierScanner(_logger, i, tier._path);
			var tierFiles = scanner.Scan();
			results[i] = tierFiles;
			sizeSums[i] = tierFiles.Sum(f => f.Size);
		});

		_sizes = sizeSums;

		var totalFiles = results.Sum(r => r.Count);
		var all = new List<FileEntry>(totalFiles);
		foreach (var r in results)
			all.AddRange(r);

		_logger.LogInformation("Total files found: {FileCount}", all.Count);
		for (int i = 0; i < _tiers.Count; i++)
			_logger.LogDebug("Tier {TierIndex} size: {Size} bytes", i, Sizes[i]);

		return all;
	}
}
