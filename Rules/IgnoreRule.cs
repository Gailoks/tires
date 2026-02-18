using Tires.Primitives;

namespace Tires.Rules;

/// <summary>
/// Rule that marks files to be excluded from moving.
/// Works at folder level - all files in matching folders are excluded.
/// </summary>
public class IgnoreRule : IRule
{
    public int CalculateScore(FileEntry entry)
    {
        // This rule doesn't calculate score for sorting
        // It's only used for exclusion
        return 0;
    }

    public bool ShouldExclude(FileEntry entry)
    {
        // IgnoreRule excludes files based on folder path matching
        // The actual exclusion logic is handled in StoragePlanner.SeparateExcludedFiles
        // This method always returns true when called from the exclusion check
        // because the folder matching is done separately
        return true;
    }
}
