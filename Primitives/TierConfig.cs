namespace Tires.Primitives;

public class TierConfig
{
    public int Target { get; set; }       // 0..100
    public string Path { get; set; } = ""; // root path of tier
}
