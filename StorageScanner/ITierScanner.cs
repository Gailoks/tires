using Tires.Primitives;
namespace Tires.Storage;

public interface ITierScanner
{
    public List<FileEntry> Scan();
}