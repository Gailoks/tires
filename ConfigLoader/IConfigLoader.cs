using Tires.Primitives;
namespace Tires.Config;

public interface IConfigLoader
{
    Configuration LoadStorageConfig(string path);
    List<FolderPlan> BuildFolderPlans(Configuration config);
}