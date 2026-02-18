namespace Tires.Primitives;

public class FolderPlanConfig
{
    public string PathPrefix { get; set; } = "";
    public int Priority { get; set; }
    public string RuleType { get; set; } = "Size";
    public bool Reverse { get; set; }
    public string? Pattern { get; set; }
    public string? TimeType { get; set; }
}
