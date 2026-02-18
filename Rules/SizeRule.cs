using Tires.Primitives;

namespace Tires.Rules;

public class SizeRule : IRule
{
    private readonly bool _reverse;

    public SizeRule(bool reverse = false)
    {
        _reverse = reverse;
    }

    public int CalculateScore(FileEntry entry)
    {
        int score = (int)(entry.Size / 1024);
        return _reverse ? -score : score;
    }
}
