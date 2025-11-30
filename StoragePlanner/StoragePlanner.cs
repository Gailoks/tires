using Microsoft.Extensions.Logging;
using Tires.Primitives;
using Tires.Config;
using System.Drawing;
namespace Tires.Storage;

public class StoragePlanner : IStoragePlanner
{
	private readonly ILogger<StorageScanner> _logger;
	private List<Tier> _tiers;
	public long[] Sizes { get; set; }
	public StoragePlanner(ILogger<StorageScanner> logger, Configuration configuration)
	{
		_logger = logger;
		_tiers = configuration.Tiers
			.Select(tc => new Tier(tc))
			.ToList();
		Sizes = new long[_tiers.Count];
	}


	public List<int> Distribute(List<FileEntry> files)
	{
		_logger.LogInformation("Distribution started");
		List<int> indexes = new();
		int currentIndex = 0;

		for(int a = 0; a < _tiers.Count; a++)
		{
			var tier = _tiers[a];
			var size = Sizes[a]; // Real size movable files
			long allowedBytes = tier.Free  + size; // Overall approved space for target without immovable data
			_logger.LogDebug("Tier allowed bytes: {Allowed}",allowedBytes);
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
		var start = 0;
		for (int i = 0; i < _tiers.Count; i++)
		{
			_logger.LogDebug($"Indexes for distribution: {start} - {indexes[i]} for Tier {i}");
			start = indexes[i] + 1;
		}
		return indexes;
	}

}