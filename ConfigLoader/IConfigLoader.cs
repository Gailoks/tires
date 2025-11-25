namespace Tires.Config;

public interface IConfigLoader
{
    Configuration LoadStorageConfig(string path);
}