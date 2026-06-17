/// Namespace for the generic Unicode kernel: canonical decomposition (NFD), case-folding, and the
/// binary-searchable property sets shared by the SQL full-text tokenizers and the document
/// content/embedding pipelines. Built on ``ADFCore`` byte buffers and the standard library's
/// Unicode database; Foundation-free and table-driven (no live recursion in decomposition).
public enum ADFUnicode {}
