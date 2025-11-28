using Tires.Primitives;
namespace Tires.Storage;

public interface ITierScanner
{
	
    public Task<List<FileEntry>> Scan();
}