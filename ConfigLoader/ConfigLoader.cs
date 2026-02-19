using System.Text.Json;
using System.Text.Json.Nodes;
using Tires.Primitives;
using Tires.Rules;
using Microsoft.Extensions.Logging;
namespace Tires.Config;

public class ConfigLoader : IConfigLoader
{
    public Configuration LoadStorageConfig(string path)
    {
        string json = File.ReadAllText(path);
        using JsonDocument doc = JsonDocument.Parse(json);
        JsonElement root = doc.RootElement;

        var config = new Configuration
        {
            IterationLimit = root.GetProperty("IterationLimit").GetInt32(),
            LogLevel = ParseLogLevel(root.GetProperty("LogLevel").GetString() ?? "Information"),
            TemporaryPath = root.GetProperty("TemporaryPath").GetString() ?? "tmp"
        };

        // Parse Tiers
        var tiers = new List<TierConfig>();
        if (root.TryGetProperty("Tiers", out var tiersElem))
        {
            foreach (var tierElem in tiersElem.EnumerateArray())
            {
                tiers.Add(new TierConfig
                {
                    Target = tierElem.GetProperty("target").GetInt32(),
                    Path = tierElem.GetProperty("path").GetString() ?? "",
                    MockCapacity = tierElem.TryGetProperty("MockCapacity", out var mc) ? mc.GetInt64() : null
                });
            }
        }
        config.Tiers = tiers;

        // Parse FolderRules (optional)
        var rules = new List<FolderPlanConfig>();
        if (root.TryGetProperty("FolderRules", out var rulesElem))
        {
            foreach (var ruleElem in rulesElem.EnumerateArray())
            {
                rules.Add(new FolderPlanConfig
                {
                    PathPrefix = ruleElem.GetProperty("PathPrefix").GetString() ?? "",
                    Priority = ruleElem.GetProperty("Priority").GetInt32(),
                    RuleType = ruleElem.GetProperty("RuleType").GetString() ?? "Size",
                    Pattern = ruleElem.TryGetProperty("Pattern", out var p) ? p.GetString() : null,
                    TimeType = ruleElem.TryGetProperty("TimeType", out var tt) ? tt.GetString() : null,
                    Reverse = ruleElem.TryGetProperty("Reverse", out var r) && r.GetBoolean()
                });
            }
        }
        config.FolderRules = rules.Count > 0 ? rules : null;

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

    private static LogLevel ParseLogLevel(string? level)
    {
        return level?.ToLower() switch
        {
            "debug" => LogLevel.Debug,
            "warning" => LogLevel.Warning,
            "error" => LogLevel.Error,
            _ => LogLevel.Information
        };
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

    private static IRule CreateRule(string ruleType, string? pattern, string? timeType)
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

    private static TimeType ParseTimeType(string? timeType)
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
