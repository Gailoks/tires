using Microsoft.Extensions.Logging;
using Tires.Primitives;
namespace Tires.Config;

public class Configuration
{
    // Parameterless constructor for JSON deserialization (AOT compatible)
    public Configuration()
    {
        Tiers = new List<TierConfig>();
        IterationLimit = 20;
        LogLevel = LogLevel.Information;
        TemporaryPath = "tmp";
    }
    
    public List<TierConfig> Tiers { get; set; }
    public int IterationLimit { get; set; }
    public LogLevel LogLevel { get; set; }
    public string TemporaryPath { get; set; }
    public List<FolderPlanConfig>? FolderRules { get; set; }
}
