using Tires.Primitives;

namespace Tires.Rules;

public enum TimeType
{
    Access,
    Modify,
    Change
}

public class TimeRule : IRule
{
    private readonly TimeType _timeType;
    private readonly bool _reverse;

    public TimeRule(TimeType timeType = TimeType.Modify, bool reverse = false)
    {
        _timeType = timeType;
        _reverse = reverse;
    }

    public int CalculateScore(FileEntry entry)
    {
        int score = _timeType switch
        {
            TimeType.Access => (int)entry.AccessTime.tv_sec,
            TimeType.Modify => (int)entry.ModifyTime.tv_sec,
            TimeType.Change => (int)entry.ChangeTime.tv_sec,
            _ => (int)entry.ModifyTime.tv_sec
        };
        
        return _reverse ? -score : score;
    }
}
