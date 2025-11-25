using System.Text.Json;
using System.Text.Json.Serialization;
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

        // 🌟 Добавить ЭТО обязательно
        options.Converters.Add(new JsonStringEnumConverter());

        var config = JsonSerializer.Deserialize<Configuration>(json, options)
                     ?? throw new Exception("Invalid storage config");

        Console.WriteLine("Number of tiers: {0}", config.Tiers.Count);
        Console.WriteLine("Iteration Limit: {0}", config.IterationLimit);
        Console.WriteLine("Log level from config: {0}", config.LogLevel);

        return config;
    }
}
