using SoftOmni.Parsing.Commons.Formatting.Parameters;

namespace SoftOmni.Parsing.Commons.Formatting;

/// <summary>
///     A contract for an object which has code that can be formatted according to a set of parameters.
/// </summary>
public interface IFormattable
{
    /// <summary>
    ///     Formats the object's related code according to the given <paramref name="parameters"/>.
    /// </summary>
    /// <param name="parameters">
    ///     The parameters to use for formatting.
    /// </param>
    public void Format(FormattingParameters parameters);
}