using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Tires.Config;
using Tires.Storage;

var configPath = args.Length > 0 ? args[0] : "storage.json";
var configLoader = new ConfigLoader();
var storageConfig = configLoader.LoadStorageConfig(configPath);
var folderPlans = configLoader.BuildFolderPlans(storageConfig);

var serviceProvider = new ServiceCollection()
    .AddLogging(builder =>
    {
        builder.AddSimpleConsole(options =>
        {
            options.IncludeScopes = true;
            options.SingleLine = true;
            options.TimestampFormat = "yyyy-MM-dd HH:mm:ss ";
        });
        builder.SetMinimumLevel(storageConfig.LogLevel);
    })
    .AddSingleton(storageConfig)
    .AddSingleton<IStorageScanner, StorageScanner>()
    .AddSingleton<ITierMover, TierMover>()
    .BuildServiceProvider();

var logger = serviceProvider.GetRequiredService<ILogger<Program>>();

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

