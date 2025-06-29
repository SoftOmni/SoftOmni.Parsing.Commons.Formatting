using System.Collections;
using System.Diagnostics.CodeAnalysis;

namespace SoftOmni.Parsing.Commons.Formatting.Parameters;

public class ReadOnlyFormattingParameters : IReadOnlyDictionary<string, FormattingParameter>
{
    protected Dictionary<string, FormattingParameter> Parameters { get; } = new();
    
    public ReadOnlyFormattingParameters() {}

    public ReadOnlyFormattingParameters(IDictionary<string, FormattingParameter> parameters)
    {
        foreach ((string key, FormattingParameter value) in parameters)
        {
            Parameters.Add(key, value);
        }
    }

    public ReadOnlyFormattingParameters(params (string key, FormattingParameter value)[] parameters)
    {
        foreach ((string key, FormattingParameter value) in parameters)
        {
            Parameters.Add(key, value);
        }
    }

    public ReadOnlyFormattingParameters(IEnumerable<(string key, FormattingParameter value)> parameters)
    {
        foreach ((string key, FormattingParameter value) in parameters)
        {
            Parameters.Add(key, value);
        }
    }

    public ReadOnlyFormattingParameters(IEnumerator<(string key, FormattingParameter value)> parameters)
    {
        while (!parameters.MoveNext())
        {
            Parameters.Add(parameters.Current.key, parameters.Current.value);
        }
    }

    public ReadOnlyFormattingParameters(ReadOnlyFormattingParameters parameters)
        : this(parameters.Parameters)
    { }

    public IEnumerator<KeyValuePair<string, FormattingParameter>> GetEnumerator()
    {
        return Parameters.GetEnumerator();
    }

    IEnumerator IEnumerable.GetEnumerator()
    {
        return GetEnumerator();
    }

    public int Count => Parameters.Count;
    
    public bool ContainsKey(string key)
    {
        return Parameters.ContainsKey(key);
    }

    public bool TryGetValue(string key, [MaybeNullWhen(false)] out FormattingParameter value)
    {
        return Parameters.TryGetValue(key, out value);
    }

    public FormattingParameter this[string key] => Parameters[key];

    public IEnumerable<string> Keys => Parameters.Keys;
    
    public IEnumerable<FormattingParameter> Values => Parameters.Values;
}