using Tires.Primitives;
using Microsoft.Extensions.Logging;
using Tires.Config;

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
		var files = GetAllFilesAsync().Result;
		return files.OrderBy(f => f.Size).ToList();
	}

	private async Task<List<FileEntry>> GetAllFilesAsync()
	{
		_logger.LogInformation("Storage scan started");

		var tasks = _tiers
			.Select((tier, index) =>
			{
				var scanner = new TierScanner(_logger, index, tier._path);
				var result = scanner.Scan();
				return result;
			})
			.ToList();

		var results = await Task.WhenAll(tasks);
		_sizes = results
		.Select(x => x.Sum(f => f.Size))
		.ToArray();

		var all = results.SelectMany(x => x).ToList();
		_logger.LogInformation("Total files found: {FileCount}", all.Count);
		for (int i = 0; i < _tiers.Count; i++)
			_logger.LogDebug("Real size of tier: {Tier}\n size: {Size}", i, Sizes[i]);


		return all;
	}
}
