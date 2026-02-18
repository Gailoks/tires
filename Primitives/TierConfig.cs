namespace Tires.Primitives;

public class TierConfig
{
    public int Target { get; set; }       // 0..100
    public string Path { get; set; } = ""; // root path of tier
    public long? MockCapacity { get; set; } // Optional: mock capacity in bytes for testing
}
