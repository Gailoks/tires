using Tires.Primitives;
using Microsoft.Extensions.Logging;
using Tires.Config;
namespace Tires.Storage;

public class StorageScanner : IStorageScanner
{
	private readonly ILogger<StorageScanner> _logger;
	private List<Tier> _tiers;

	public StorageScanner(ILogger<StorageScanner> logger, Configuration configuration)
	{
		_logger = logger;
		_tiers = configuration.Tiers
		.Select(tc => new Tier(tc))
		.ToList();
	}

	public List<FileEntry> GetSortedFiles()
	{
		var files = GetAllFiles();
		var allFiles = files.OrderBy(f => f.Size).ToList();

		return allFiles;
	}
	private List<FileEntry> GetAllFiles()
	{
		var result = new List<FileEntry>();
		int index = 0;

		foreach (Tier tier in _tiers)
		{
			foreach (var file in Directory.EnumerateFiles(tier._path, "*", SearchOption.AllDirectories))
			{
				var info = new FileInfo(file);
				result.Add(new FileEntry
				{
					Path = file,
					Size = info.Length,
					TierIndex = index
				});

				_logger.LogDebug("Found file: {FilePath} ({FileSize} bytes)", file, info.Length);
			}
			index ++;
		}


		_logger.LogInformation("Total files found: {FileCount}", result.Count);
		return result;
	}
}
