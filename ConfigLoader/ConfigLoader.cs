using System.Text.Json;
using System.Text.Json.Serialization;
using Tires.Primitives;
using Tires.Rules;
namespace Tires.Config;

public class ConfigLoader : IConfigLoader
{
    public Configuration LoadStorageConfig(string path)
    {
        string json = File.ReadAllText(path);

        var options = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        };

        options.Converters.Add(new JsonStringEnumConverter());

        var config = JsonSerializer.Deserialize<Configuration>(json, options)
                     ?? throw new Exception("Invalid storage config");

        Console.WriteLine("Number of tiers: {0}", config.Tiers.Count);
        Console.WriteLine("Iteration Limit: {0}", config.IterationLimit);
        Console.WriteLine("Log level from config: {0}", config.LogLevel);
		Console.WriteLine("Temporary path from config: {0}", config.TemporaryPath);

        if (config.FolderRules != null)
        {
            foreach (var folderRule in config.FolderRules)
            {
                Console.WriteLine($"Folder rule: {folderRule.PathPrefix} (priority: {folderRule.Priority}, rule: {folderRule.RuleType})");
            }
        }

        return config;
    }

    public List<FolderPlan> BuildFolderPlans(Configuration config)
    {
        if (config.FolderRules == null)
            return new List<FolderPlan>();

        return config.FolderRules.Select(f => new FolderPlan(
            f.PathPrefix,
            f.Priority,
            CreateRule(f.RuleType, f.Pattern, f.TimeType),
            f.Reverse
        )).ToList();
    }

    private IRule CreateRule(string ruleType, string? pattern, string? timeType, long? maxSize = null, long? minSize = null)
    {
        return ruleType.ToLower() switch
        {
            "name" => new NameRule(pattern),
            "size" => new SizeRule(),
            "time" => new TimeRule(ParseTimeType(timeType)),
            "ignore" => new IgnoreRule(),
            _ => new SizeRule()
        };
    }

    private TimeType ParseTimeType(string? timeType)
    {
        return timeType?.ToLower() switch
        {
            "access" => TimeType.Access,
            "modify" => TimeType.Modify,
            "change" => TimeType.Change,
            _ => TimeType.Modify
        };
    }
}
