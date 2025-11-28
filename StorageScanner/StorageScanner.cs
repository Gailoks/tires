using Tires.Primitives;
using Microsoft.Extensions.Logging;
using Tires.Config;

namespace Tires.Storage;

public class StorageScanner : IStorageScanner
{
    private readonly ILogger<StorageScanner> _logger;
    private readonly List<Tier> _tiers;

    public StorageScanner(ILogger<StorageScanner> logger, Configuration configuration)
    {
        _logger = logger;
        _tiers = configuration.Tiers
            .Select(tc => new Tier(tc))
            .ToList();
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
                return scanner.Scan();
            })
            .ToList();

        var results = await Task.WhenAll(tasks);

        var all = results.SelectMany(x => x).ToList();
        _logger.LogInformation("Total files found: {FileCount}", all.Count);

        return all;
    }
}
