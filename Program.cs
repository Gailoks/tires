using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Tires.Config;
using Tires.Storage;
using System.Diagnostics;
using Tires;

var configPath = args.Length > 0 ? args[0] : "storage.json";
var configLoader = new ConfigLoader();
var storageConfig = configLoader.LoadStorageConfig(configPath);
var folderPlans = configLoader.BuildFolderPlans(storageConfig);

var serviceProvider = new ServiceCollection()
    .AddLogging(builder =>
    {
        builder.SetMinimumLevel(storageConfig.LogLevel);
        
        // Console output
        builder.AddSimpleConsole(options =>
        {
            options.IncludeScopes = true;
            options.SingleLine = true;
            options.TimestampFormat = "yyyy-MM-dd HH:mm:ss ";
        });
        
        // File output
        builder.AddSimpleFileLogger(storageConfig.LogPath, storageConfig.LogLevel);
    })
    .AddSingleton(storageConfig)
    .AddSingleton<IStorageScanner, StorageScanner>()
    .AddSingleton<ITierMover, TierMover>()
    .BuildServiceProvider();

var logger = serviceProvider.GetRequiredService<ILogger<Program>>();

// Set process priority
try
{
    using var process = Process.GetCurrentProcess();
    // Priority class mapping based on nice-like values (-20 to 19)
    // Default: Idle - runs only when CPU is otherwise idle (best for background tasks)
    process.PriorityClass = storageConfig.ProcessPriority switch
    {
        < 0 => ProcessPriorityClass.AboveNormal,   // High priority
        0 => ProcessPriorityClass.Normal,          // Normal priority
        1 => ProcessPriorityClass.BelowNormal,     // Low priority
        _ => ProcessPriorityClass.Idle             // Idle (default, 2-19)
    };
    logger.LogInformation("Process priority set to: {Priority} (nice: {Nice})",
        process.PriorityClass, storageConfig.ProcessPriority);
}
catch (Exception ex)
{
    logger.LogWarning(ex, "Failed to set process priority");
}

logger.LogInformation("=== Tires - Tiered Storage Manager ===");
logger.LogInformation("Configuration loaded from: {ConfigPath}", configPath);
logger.LogInformation("Number of tiers: {TierCount}", storageConfig.Tiers.Count);
logger.LogInformation("Iteration limit: {IterationLimit}", storageConfig.IterationLimit);
logger.LogInformation("Log level: {LogLevel}", storageConfig.LogLevel);
logger.LogInformation("Temporary path: {TemporaryPath}", storageConfig.TemporaryPath);

foreach (var tier in storageConfig.Tiers.Select((t, i) => (t, i)))
{
    logger.LogInformation("Tier {Index}: Path={Path}, Target={Target}%", 
        tier.i, tier.t.Path, tier.t.Target);
}

if (storageConfig.FolderRules != null && storageConfig.FolderRules.Any())
{
    foreach (var rule in storageConfig.FolderRules)
    {
        logger.LogInformation("Folder rule: Path={PathPrefix}, Priority={Priority}, Rule={RuleType}", 
            rule.PathPrefix, rule.Priority, rule.RuleType);
    }
}

var scanner = serviceProvider.GetRequiredService<IStorageScanner>();
var mover = serviceProvider.GetRequiredService<ITierMover>();
var plannerLogger = serviceProvider.GetRequiredService<ILogger<StoragePlanner>>();
var planner = new StoragePlanner(plannerLogger, storageConfig, folderPlans);

var files = scanner.GetSortedFiles();

logger.LogInformation("Files found: {FileCount}", files.Count);

planner.Sizes = scanner.Sizes;
var (sortedFiles, indexes) = planner.Distribute(files);

logger.LogInformation("Files to move: {MoveCount} (excluded: {ExcludedCount})", 
    sortedFiles.Count, files.Count - sortedFiles.Count);

mover.ApplyPlan(sortedFiles, indexes);

logger.LogInformation("=== Tires operation completed ===");

