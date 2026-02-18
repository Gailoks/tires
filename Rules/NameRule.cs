using Tires.Primitives;

namespace Tires.Rules;

public class NameRule : IRule
{
    private readonly string? _pattern;
    private readonly bool _reverse;

    public NameRule(string? pattern = null, bool reverse = false)
    {
        _pattern = pattern;
        _reverse = reverse;
    }

    public int CalculateScore(FileEntry entry)
    {
        var fileName = Path.GetFileName(entry.Paths[0]);
        
        if (_pattern != null)
        {
            return fileName.Contains(_pattern, StringComparison.OrdinalIgnoreCase) ? 1 : 0;
        }
        
        int score = fileName.GetHashCode();
        return _reverse ? -score : score;
    }
}
