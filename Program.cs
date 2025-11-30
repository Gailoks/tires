using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Tires.Config;
using Tires.Storage;

var configLoader = new ConfigLoader();
var storageConfig = configLoader.LoadStorageConfig("storage.json");

var serviceProvider = new ServiceCollection()
    .AddLogging(builder =>
    {
        builder.AddSimpleConsole(options =>
        {
            options.IncludeScopes = false;
            options.SingleLine = true;
            options.TimestampFormat = "[HH:mm:ss] ";
        });
        builder.SetMinimumLevel(storageConfig.LogLevel);
    })
	.AddSingleton(storageConfig)
    .AddSingleton<IStorageScanner, StorageScanner>()
	.AddSingleton<IStoragePlanner, StoragePlanner>()
	.AddSingleton<ITierMover, TierMover>()
    .BuildServiceProvider();


var scanner = serviceProvider.GetRequiredService<IStorageScanner>();
var planner = serviceProvider.GetRequiredService<IStoragePlanner>();
var mover = serviceProvider.GetRequiredService<ITierMover>();

var files = scanner.GetSortedFiles();

planner.Sizes = scanner.Sizes;
var indexes = planner.Distribute(files);

mover.ApplyPlan(files,indexes);

