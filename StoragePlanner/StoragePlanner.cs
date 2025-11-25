using Microsoft.Extensions.Logging;
using Tires.Primitives;
using Tires.Config;
namespace Tires.Storage;
public class StoragePlanner : IStoragePlanner
{	
	private readonly ILogger<StorageScanner> _logger;
	private List<Tier> _tiers;
	public StoragePlanner(ILogger<StorageScanner> logger, Configuration configuration)
    {
        _logger = logger;
		_tiers = configuration.Tiers
    		.Select(tc => new Tier(tc))
    		.ToList();
    }


	public List<int> Distribute(List<FileEntry> files)
	{
		_logger.LogInformation("Distribution started");
		List<int> indexes = new();
		int currentIndex = 0;

		foreach (var tier in _tiers)
		{
			long allowedBytes = tier.AllowedSpace;
			long cumulative = 0;
			int lastIndex = currentIndex - 1;

			for (int i = currentIndex; i < files.Count; i++)
			{
				if (cumulative + files[i].Size <= allowedBytes)
				{
					cumulative += files[i].Size;
					lastIndex = i;
				}
				else
				{
					break;
				}
			}

			indexes.Add(lastIndex);
			currentIndex = lastIndex + 1;
		}
		_logger.LogInformation("Distribution finished");
		return indexes;
	}

}