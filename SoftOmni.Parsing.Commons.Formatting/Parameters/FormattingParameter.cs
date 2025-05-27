namespace SoftOmni.Parsing.Commons.Formatting.Parameters;

public abstract class FormattingParameter : IEquatable<FormattingParameter>, IEqualityComparer<FormattingParameter>,
    IEquatable<string>, IEqualityComparer<string>
{
    public Guid Id { get; } = Guid.NewGuid();
    
    public string Value { get; private set; }

    protected FormattingParameter()
    {
        // ReSharper disable once VirtualMemberCallInConstructor
        Value = ToValueString();
    }

    protected FormattingParameter(string value)
    {
        Value = value;
    }

    protected FormattingParameter(FormattingParameter parameter)
    {
        Value = parameter.Value;
    }
    
    protected abstract string ToValueString();
    
    public override string ToString()
    {
        return Value;
    }

    public bool Equals(string? other)
    {
        return other is not null && Value == other;
    }

    public bool Equals(FormattingParameter? other)
    {
        return other is not null && Id == other.Id;
    }

    public override bool Equals(object? obj)
    {
        return obj switch
        {
            FormattingParameter parameter => Id == parameter.Id,
            string value => Value == value,
            _ => false
        };
    }

    public bool Equals(FormattingParameter? x, FormattingParameter? y)
    {
        if (ReferenceEquals(x, y)) return true;
        if (x is null || y is null) return false;
        return x.Id.Equals(y.Id);
    }

    public bool Equals(string? x, string? y)
    {
        if (ReferenceEquals(x, y)) return true;
        if (x is null || y is null) return false;
        return x.Equals(y);
    }

    public override int GetHashCode()
    {
        return Id.GetHashCode();
    }
    
    public int GetHashCode(FormattingParameter obj)
    {
        return obj.Id.GetHashCode();
    }

    public int GetHashCode(string obj)
    {
        return obj.GetHashCode();
    }
}
