namespace SoftOmni.Parsing.Commons.Formatting.Parameters;

public class FormattingParameters : ReadOnlyFormattingParameters, IDictionary<string, FormattingParameter>
{
    public FormattingParameters()
    { }

    public FormattingParameters(IDictionary<string, FormattingParameter> parameters)
        : base(parameters)
    { }

    public FormattingParameters(params (string key, FormattingParameter value)[] parameters)
        : base(parameters)
    { }

    public FormattingParameters(IEnumerable<(string key, FormattingParameter value)> parameters)
        : base(parameters)
    { }

    public FormattingParameters(IEnumerator<(string key, FormattingParameter value)> parameters)
        : base(parameters)
    { }

    public FormattingParameters(ReadOnlyFormattingParameters parameters)
        : base(parameters)
    { }


    public void Add(KeyValuePair<string, FormattingParameter> item)
    {
        Parameters.Add(item.Key, item.Value);
    }

    public void Clear()
    {
        Parameters.Clear();
    }

    public bool Contains(KeyValuePair<string, FormattingParameter> item)
    {
        return Parameters.Contains(item);
    }

    public void CopyTo(KeyValuePair<string, FormattingParameter>[] array, int arrayIndex)
    {
        if (array is null)
        {
            throw new ArgumentNullException(nameof(array));
        }

        if (arrayIndex < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(arrayIndex));
        }

        if (array.Length - arrayIndex < Count)
        {
            throw new ArgumentException(
                "The number of elements in the source FormattingParameters " +
                "is greater than the available space from arrayIndex to " +
                "the end of the destination array.");
        }
        
        foreach (var (key, value) in Parameters)
        {
            array[arrayIndex++] = new KeyValuePair<string, FormattingParameter>(key, value);
        }
    }

    public bool Remove(KeyValuePair<string, FormattingParameter> item)
    {
        return Remove(item.Key);
    }

    public bool IsReadOnly => false;

    public void Add(string key, FormattingParameter value)
    {
        Parameters.Add(key, value);
    }

    public bool Remove(string key)
    {
        return Parameters.Remove(key);
    }

    public new FormattingParameter this[string key]
    {
        get => base[key];
        set => Parameters[key] = value;
    }

    public new ICollection<string> Keys => Parameters.Keys;
    public new ICollection<FormattingParameter> Values => Parameters.Values;
}