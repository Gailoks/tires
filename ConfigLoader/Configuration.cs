using Microsoft.Extensions.Logging;
using Tires.Primitives;
namespace Tires.Config;
public class Configuration
{
    public required List<TierConfig> Tiers { get; set; }
	public required int IterationLimit {get; set; }
	public LogLevel LogLevel { get; set; } = LogLevel.Information;
}
