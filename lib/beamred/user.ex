defmodule BeamRED.User do
  alias BeamRED.Utils

  defstruct [:id, :name]

  @type id :: Utils.id()

  @type t :: %__MODULE__{
          id: id(),
          name: String.t() | nil
        }

  @doc """
  Generates a new user.
  """
  @spec new(String.t()) :: t()
  def new(id \\ Utils.random_long_id()) do
    %__MODULE__{
      id: id,
      name: nil
    }
  end
end
