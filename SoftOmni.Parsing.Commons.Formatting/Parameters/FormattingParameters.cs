namespace SoftOmni.Parsing.Commons.Formatting.Parameters;

public class FormattingParameters
{
    public Dictionary<string, FormattingParameter> Parameters { get; } = new();
    
    public FormattingParameters() {}

    public FormattingParameters(IDictionary<string, FormattingParameter> parameters)
    {
        foreach ((string key, FormattingParameter value) in parameters)
        {
            Parameters.Add(key, value);
        }
    }

    public FormattingParameters(params (string key, FormattingParameter value)[] parameters)
    {
        foreach ((string key, FormattingParameter value) in parameters)
        {
            Parameters.Add(key, value);
        }
    }

    public FormattingParameters(IEnumerable<(string key, FormattingParameter value)> parameters)
    {
        foreach ((string key, FormattingParameter value) in parameters)
        {
            Parameters.Add(key, value);
        }
    }

    public FormattingParameters(IEnumerator<(string key, FormattingParameter value)> parameters)
    {
        while (!parameters.MoveNext())
        {
            Parameters.Add(parameters.Current.key, parameters.Current.value);
        }
    }

    public FormattingParameters(FormattingParameters parameters)
        : this(parameters.Parameters)
    { }
}