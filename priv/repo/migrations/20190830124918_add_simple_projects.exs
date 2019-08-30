defmodule PaperTrail.Repo.Migrations.AddSimpleProjects do
  use Ecto.Migration

  def change do
    create table(:simple_projects) do
      add :name,       :string, null: false

      add :person_id, references(:simple_people), null: false

      timestamps()
    end
  end
end
