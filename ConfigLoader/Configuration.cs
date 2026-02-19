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
        RunInterval = "hourly";
    }
    
    public List<TierConfig> Tiers { get; set; }
    public int IterationLimit { get; set; }
    public LogLevel LogLevel { get; set; }
    public string TemporaryPath { get; set; }
    public List<FolderPlanConfig>? FolderRules { get; set; }
    
    /// <summary>
    /// How often to run the storage optimization.
    /// Supported values: "minutely", "hourly", "daily", "weekly", "monthly", 
    /// or systemd calendar format (e.g., "*-*-* 02:00:00" for daily at 2 AM)
    /// </summary>
    public string RunInterval { get; set; }
}
