namespace Tires.Primitives;

public interface IRule
{
	int CalculateScore(FileEntry entry);
	
	/// <summary>
	/// Checks if a file should be excluded from moving.
	/// Default implementation returns false (file can be moved).
	/// </summary>
	/// <param name="entry">The file entry to check</param>
	/// <returns>True if the file should NOT be moved, false otherwise</returns>
	bool ShouldExclude(FileEntry entry) => false;
}