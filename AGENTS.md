# Repository guidance

Read [structure.md](structure.md) before changing this repository. Follow its
Terraform layering, explicit module composition, root tfvars configuration,
module output, and verification conventions for new and modified code.

Preserve unrelated user edits. Do not apply live infrastructure changes unless
requested. When the user changes a convention, update structure.md alongside
the implementation.
