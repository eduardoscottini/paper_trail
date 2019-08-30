defmodule SimpleCompany do
  use Ecto.Schema

  alias PaperTrailTest.MultiTenantHelper, as: MultiTenant

  import Ecto.Changeset
  import Ecto.Query

  schema "simple_companies" do
    field(:name, :string)
    field(:is_active, :boolean)
    field(:website, :string)
    field(:city, :string)
    field(:address, :string)
    field(:facebook, :string)
    field(:twitter, :string)
    field(:founded_in, :string)

    has_many(:people, SimplePerson, foreign_key: :company_id)

    timestamps()
  end

  @optional_fields ~w(name is_active website city address facebook twitter founded_in)a

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @optional_fields)
    |> validate_required([:name])
    |> no_assoc_constraint(:people)
    |> cast_assoc(:people, with: &SimplePerson.changeset/2)
  end

  def count do
    from(record in __MODULE__, select: count(record.id)) |> PaperTrail.RepoClient.repo().one
  end

  def count(:multitenant) do
    from(record in __MODULE__, select: count(record.id))
    |> MultiTenant.add_prefix_to_query()
    |> PaperTrail.RepoClient.repo().one
  end
end

defmodule SimplePerson do
  use Ecto.Schema

  alias PaperTrailTest.MultiTenantHelper, as: MultiTenant

  import Ecto.Changeset
  import Ecto.Query

  schema "simple_people" do
    field(:first_name, :string)
    field(:last_name, :string)
    field(:visit_count, :integer)
    field(:gender, :boolean)
    field(:birthdate, :date)

    belongs_to(:company, SimpleCompany, foreign_key: :company_id)

    has_one(:project, SimpleProject, foreign_key: :person_id)

    timestamps()
  end

  @optional_fields ~w(first_name last_name visit_count gender birthdate company_id)a

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @optional_fields)
    |> foreign_key_constraint(:company_id)
    |> cast_assoc(:project, with: &SimpleProject.changeset/2)
  end

  def count do
    from(record in __MODULE__, select: count(record.id)) |> PaperTrail.RepoClient.repo().one
  end

  def count(:multitenant) do
    from(record in __MODULE__, select: count(record.id))
    |> MultiTenant.add_prefix_to_query()
    |> PaperTrail.RepoClient.repo().one
  end
end

defmodule SimpleProject do
  use Ecto.Schema

  alias PaperTrailTest.MultiTenantHelper, as: MultiTenant

  import Ecto.Changeset
  import Ecto.Query

  schema "simple_projects" do
    field(:name, :string)

    belongs_to(:person, SimplePerson, foreign_key: :person_id)

    timestamps()
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:name])
    |> foreign_key_constraint(:person_id)
  end

  def count do
    from(record in __MODULE__, select: count(record.id)) |> PaperTrail.RepoClient.repo().one
  end

  def count(:multitenant) do
    from(record in __MODULE__, select: count(record.id))
    |> MultiTenant.add_prefix_to_query()
    |> PaperTrail.RepoClient.repo().one
  end
end
