defmodule PaperTrailTest do
  use ExUnit.Case

  import Ecto.Query

  alias PaperTrail.Version
  alias SimpleCompany, as: Company
  alias SimplePerson, as: Person
  alias SimpleProject, as: Project

  @repo PaperTrail.RepoClient.repo()
  @create_company_params %{name: "Acme LLC", is_active: true, city: "Greenwich"}
  @create_person_params %{first_name: "Izel", last_name: "Nakri", gender: true}
  @update_company_params %{
    city: "Hong Kong",
    website: "http://www.acme.com",
    facebook: "acme.llc"
  }

  doctest PaperTrail

  setup_all do
    Application.put_env(:paper_trail, :strict_mode, false)
    Application.put_env(:paper_trail, :repo, PaperTrail.Repo)
    Code.eval_file("lib/paper_trail.ex")
    Code.eval_file("lib/version.ex")
    :ok
  end

  setup do
    @repo.delete_all(Project)
    @repo.delete_all(Person)
    @repo.delete_all(Company)
    @repo.delete_all(Version)

    on_exit(fn ->
      @repo.delete_all(Project)
      @repo.delete_all(Person)
      @repo.delete_all(Company)
      @repo.delete_all(Version)
    end)

    :ok
  end

  test "creating a company creates a company version with correct attributes" do
    user = create_user()
    {:ok, result} = create_company_with_version(@create_company_params, originator: user)

    company_count = Company.count()
    version_count = Version.count()

    company = result[:model] |> serialize
    version = result[:version] |> serialize

    assert Map.keys(result) == [:model, :version]
    assert company_count == 1
    assert version_count == 1

    assert Map.drop(company, [:id, :inserted_at, :updated_at]) == %{
             name: "Acme LLC",
             is_active: true,
             city: "Greenwich",
             website: nil,
             address: nil,
             facebook: nil,
             twitter: nil,
             founded_in: nil
           }

    assert Map.drop(version, [:id, :inserted_at]) == %{
             event: "insert",
             item_type: "SimpleCompany",
             item_id: company.id,
             item_changes: company,
             originator_id: user.id,
             origin: nil,
             meta: nil
           }

    assert company == first(Company, :id) |> @repo.one |> serialize
  end

  test "PaperTrail.insert/2 with an error returns and error tuple like Repo.insert/2" do
    result = create_company_with_version(%{name: nil, is_active: true, city: "Greenwich"})

    ecto_result =
      Company.changeset(%Company{}, %{name: nil, is_active: true, city: "Greenwich"})
      |> @repo.insert

    assert result == ecto_result
  end

  test "updating a company with originator creates a correct company version" do
    user = create_user()
    {:ok, insert_result} = create_company_with_version()

    {:ok, result} =
      update_company_with_version(
        insert_result[:model],
        @update_company_params,
        user: user
      )

    company_count = Company.count()
    version_count = Version.count()

    company = result[:model] |> serialize
    version = result[:version] |> serialize

    assert Map.keys(result) == [:model, :version]
    assert company_count == 1
    assert version_count == 2

    assert Map.drop(company, [:id, :inserted_at, :updated_at]) == %{
             name: "Acme LLC",
             is_active: true,
             city: "Hong Kong",
             website: "http://www.acme.com",
             address: nil,
             facebook: "acme.llc",
             twitter: nil,
             founded_in: nil
           }

    assert Map.drop(version, [:id, :inserted_at]) == %{
             event: "update",
             item_type: "SimpleCompany",
             item_id: company.id,
             item_changes: %{
               city: "Hong Kong",
               website: "http://www.acme.com",
               facebook: "acme.llc"
             },
             originator_id: user.id,
             origin: nil,
             meta: nil
           }

    assert company == first(Company, :id) |> @repo.one |> serialize
  end

  test "updating a company with association update should create a correct company version" do
    user = create_user()
    # {:ok, %{model: company_model, version: version_model} = insert_result} = create_company_with_version(@create_company_with_assocs_params)
    {:ok, %{model: company} = insert_result} = create_company_with_version()
    {:ok, %{model: person_model} = insert_result} = create_person_with_version(company)

    company = company |> @repo.preload(people: [:project])


    company_update_params = %{
      name: "Acme LLC",
      is_active: true,
      city: "Hong Kong",
      website: "http://www.acme.com",
      facebook: "acme.llc",
      people: [
        %{
          id: person_model.id,
          first_name: "Doctor",
          last_name: "Strange",
          gender: true,
          project: %{name: "Project X"}
        }
      ]
    }

    {:ok, %{model: updated_company, version: new_version} = result} =
      update_company_with_version(
        company,
        company_update_params,
        user: user
      )

    assert Company.count() == 1
    assert Version.count() == 3
    assert Person.count() == 1
    assert Project.count() == 1

    updated_company = updated_company |> @repo.preload(people: [:project])
    assert %{
      city: "Hong Kong",
      facebook: "acme.llc",
      website: "http://www.acme.com"
    } = updated_company |> serialize

    assert %{
      first_name: "Doctor",
      last_name: "Strange"
    } = List.first(updated_company.people) |> serialize

    assert %{
      event: "update",
      item_type: "SimpleCompany",
      item_id: company.id,
      item_changes: %{
        city: "Hong Kong",
        facebook: "acme.llc",
        people: [
          %{first_name: "Doctor", last_name: "Strange", project: %{name: "Project X"}}
        ],
        website: "http://www.acme.com"
      },
      originator_id: user.id,
      origin: nil,
      meta: nil
    } == Map.drop(new_version |> serialize, [:id, :inserted_at, :updated_at])
  end

  test "updating a company with originator[user] creates a correct company version" do
    user = create_user()
    {:ok, insert_result} = create_company_with_version()

    {:ok, result} =
      update_company_with_version(
        insert_result[:model],
        @update_company_params,
        user: user
      )

    company_count = Company.count()
    version_count = Version.count()

    company = result[:model] |> serialize
    version = result[:version] |> serialize

    assert Map.keys(result) == [:model, :version]
    assert company_count == 1
    assert version_count == 2

    assert Map.drop(company, [:id, :inserted_at, :updated_at]) == %{
             name: "Acme LLC",
             is_active: true,
             city: "Hong Kong",
             website: "http://www.acme.com",
             address: nil,
             facebook: "acme.llc",
             twitter: nil,
             founded_in: nil
           }

    assert Map.drop(version, [:id, :inserted_at]) == %{
             event: "update",
             item_type: "SimpleCompany",
             item_id: company.id,
             item_changes: %{
               city: "Hong Kong",
               website: "http://www.acme.com",
               facebook: "acme.llc"
             },
             originator_id: user.id,
             origin: nil,
             meta: nil
           }

    assert company == first(Company, :id) |> @repo.one |> serialize
  end

  test "PaperTrail.update/2 with an error returns and error tuple like Repo.update/2" do
    {:ok, insert_result} = create_company_with_version()
    company = insert_result[:model]

    result =
      update_company_with_version(company, %{
        name: nil,
        city: "Hong Kong",
        website: "http://www.acme.com",
        facebook: "acme.llc"
      })

    ecto_result =
      Company.changeset(company, %{
        name: nil,
        city: "Hong Kong",
        website: "http://www.acme.com",
        facebook: "acme.llc"
      })
      |> @repo.update

    assert result == ecto_result
  end

  test "deleting a company creates a company version with correct attributes" do
    user = create_user()
    {:ok, insert_result} = create_company_with_version()
    {:ok, update_result} = update_company_with_version(insert_result[:model])
    company_before_deletion = first(Company, :id) |> @repo.one |> serialize
    {:ok, result} = PaperTrail.delete(update_result[:model], originator: user)

    company_count = Company.count()
    version_count = Version.count()

    company = result[:model] |> serialize
    version = result[:version] |> serialize

    assert Map.keys(result) == [:model, :version]
    assert company_count == 0
    assert version_count == 3

    assert Map.drop(company, [:id, :inserted_at, :updated_at]) == %{
             name: "Acme LLC",
             is_active: true,
             city: "Hong Kong",
             website: "http://www.acme.com",
             address: nil,
             facebook: "acme.llc",
             twitter: nil,
             founded_in: nil
           }

    assert Map.drop(version, [:id, :inserted_at]) == %{
             event: "delete",
             item_type: "SimpleCompany",
             item_id: company.id,
             item_changes: %{
               id: company.id,
               inserted_at: company.inserted_at,
               updated_at: company.updated_at,
               name: "Acme LLC",
               is_active: true,
               website: "http://www.acme.com",
               city: "Hong Kong",
               address: nil,
               facebook: "acme.llc",
               twitter: nil,
               founded_in: nil
             },
             originator_id: user.id,
             origin: nil,
             meta: nil
           }

    assert company == company_before_deletion
  end

  test "delete works with a changeset" do
    user = create_user()
    {:ok, insert_result} = create_company_with_version()
    {:ok, update_result} = update_company_with_version(insert_result[:model])
    company_before_deletion = first(Company, :id) |> @repo.one

    changeset = Company.changeset(company_before_deletion, %{})
    {:ok, result} = PaperTrail.delete(changeset, originator: user)

    company_count = Company.count()
    version_count = Version.count()

    company = result[:model] |> serialize
    version = result[:version] |> serialize

    assert Map.keys(result) == [:model, :version]
    assert company_count == 0
    assert version_count == 3

    assert Map.drop(company, [:id, :inserted_at, :updated_at]) == %{
             name: "Acme LLC",
             is_active: true,
             city: "Hong Kong",
             website: "http://www.acme.com",
             address: nil,
             facebook: "acme.llc",
             twitter: nil,
             founded_in: nil
           }

    assert Map.drop(version, [:id, :inserted_at]) == %{
             event: "delete",
             item_type: "SimpleCompany",
             item_id: company.id,
             item_changes: %{
               id: company.id,
               inserted_at: company.inserted_at,
               updated_at: company.updated_at,
               name: "Acme LLC",
               is_active: true,
               website: "http://www.acme.com",
               city: "Hong Kong",
               address: nil,
               facebook: "acme.llc",
               twitter: nil,
               founded_in: nil
             },
             originator_id: user.id,
             origin: nil,
             meta: nil
           }

    assert company == serialize(company_before_deletion)
  end

  test "PaperTrail.delete/2 with an error returns and error tuple like Repo.delete/2" do
    {:ok, insert_company_result} = create_company_with_version()

    Person.changeset(%Person{}, %{
      first_name: "Izel",
      last_name: "Nakri",
      gender: true,
      company_id: insert_company_result[:model].id
    })
    |> PaperTrail.insert()

    ecto_result = insert_company_result[:model] |> Company.changeset() |> @repo.delete
    result = insert_company_result[:model] |> Company.changeset() |> PaperTrail.delete()

    assert result == ecto_result
  end

  test "creating a person with meta tag creates a person version with correct attributes" do
    create_company_with_version()

    {:ok, new_company_result} =
      Company.changeset(%Company{}, %{
        name: "Another Company Corp.",
        is_active: true,
        address: "Sesame street 100/3, 101010"
      })
      |> PaperTrail.insert()

    {:ok, result} =
      Person.changeset(%Person{}, %{
        first_name: "Izel",
        last_name: "Nakri",
        gender: true,
        company_id: new_company_result[:model].id
      })
      |> PaperTrail.insert(origin: "admin", meta: %{linkname: "izelnakri"})

    person_count = Person.count()
    version_count = Version.count()

    person = result[:model] |> serialize
    version = result[:version] |> serialize

    assert Map.keys(result) == [:model, :version]
    assert person_count == 1
    assert version_count == 3

    assert Map.drop(person, [:id, :inserted_at, :updated_at]) == %{
             first_name: "Izel",
             last_name: "Nakri",
             gender: true,
             visit_count: nil,
             birthdate: nil,
             company_id: new_company_result[:model].id
           }

    assert Map.drop(version, [:id, :inserted_at]) == %{
             event: "insert",
             item_type: "SimplePerson",
             item_id: person.id,
             item_changes: person,
             originator_id: nil,
             origin: "admin",
             meta: %{linkname: "izelnakri"}
           }

    assert person == first(Person, :id) |> @repo.one |> serialize
  end

  test "updating a person creates a person version with correct attributes" do
    {:ok, initial_company_insertion} =
      create_company_with_version(%{
        name: "Acme LLC",
        website: "http://www.acme.com"
      })

    {:ok, target_company_insertion} =
      create_company_with_version(%{
        name: "Another Company Corp.",
        is_active: true,
        address: "Sesame street 100/3, 101010"
      })

    {:ok, insert_person_result} =
      Person.changeset(%Person{}, %{
        first_name: "Izel",
        last_name: "Nakri",
        gender: true,
        company_id: target_company_insertion[:model].id
      })
      |> PaperTrail.insert(origin: "admin")

    {:ok, result} =
      Person.changeset(insert_person_result[:model], %{
        first_name: "Isaac",
        visit_count: 10,
        birthdate: ~D[1992-04-01],
        company_id: initial_company_insertion[:model].id
      })
      |> PaperTrail.update(origin: "scraper", meta: %{linkname: "izelnakri"})

    person_count = Person.count()
    version_count = Version.count()

    person = result[:model] |> serialize
    version = result[:version] |> serialize

    assert Map.keys(result) == [:model, :version]
    assert person_count == 1
    assert version_count == 4

    assert Map.drop(person, [:id, :inserted_at, :updated_at]) == %{
             company_id: initial_company_insertion[:model].id,
             first_name: "Isaac",
             visit_count: 10,
             birthdate: ~D[1992-04-01],
             last_name: "Nakri",
             gender: true
           }

    assert Map.drop(version, [:id, :inserted_at]) == %{
             event: "update",
             item_type: "SimplePerson",
             item_id: person.id,
             item_changes: %{
               first_name: "Isaac",
               visit_count: 10,
               birthdate: ~D[1992-04-01],
               company_id: initial_company_insertion[:model].id
             },
             originator_id: nil,
             origin: "scraper",
             meta: %{linkname: "izelnakri"}
           }

    assert person == first(Person, :id) |> @repo.one |> serialize
  end

  test "deleting a person creates a person version with correct attributes" do
    create_company_with_version(%{name: "Acme LLC", website: "http://www.acme.com"})

    {:ok, target_company_insertion} =
      create_company_with_version(%{
        name: "Another Company Corp.",
        is_active: true,
        address: "Sesame street 100/3, 101010"
      })

    # add link name later on
    {:ok, insert_person_result} =
      Person.changeset(%Person{}, %{
        first_name: "Izel",
        last_name: "Nakri",
        gender: true,
        company_id: target_company_insertion[:model].id
      })
      |> PaperTrail.insert(origin: "admin")

    {:ok, update_result} =
      Person.changeset(insert_person_result[:model], %{
        first_name: "Isaac",
        visit_count: 10,
        birthdate: ~D[1992-04-01],
        company_id: target_company_insertion[:model].id
      })
      |> PaperTrail.update(origin: "scraper", meta: %{linkname: "izelnakri"})

    person_before_deletion = first(Person, :id) |> @repo.one |> serialize

    {:ok, result} =
      PaperTrail.delete(
        update_result[:model],
        origin: "admin",
        meta: %{linkname: "izelnakri"}
      )

    person_count = Person.count()
    version_count = Version.count()

    assert Map.keys(result) == [:model, :version]
    old_person = update_result[:model] |> serialize
    version = result[:version] |> serialize

    assert person_count == 0
    assert version_count == 5

    assert Map.drop(version, [:id, :inserted_at]) == %{
             event: "delete",
             item_type: "SimplePerson",
             item_id: old_person.id,
             item_changes: %{
               id: old_person.id,
               inserted_at: old_person.inserted_at,
               updated_at: old_person.updated_at,
               first_name: "Isaac",
               last_name: "Nakri",
               gender: true,
               visit_count: 10,
               birthdate: ~D[1992-04-01],
               company_id: target_company_insertion[:model].id
             },
             originator_id: nil,
             origin: "admin",
             meta: %{linkname: "izelnakri"}
           }

    assert old_person == person_before_deletion
  end

  defp create_user do
    User.changeset(%User{}, %{token: "fake-token", username: "izelnakri"}) |> @repo.insert!
  end

  defp create_company_with_version(params \\ @create_company_params, options \\ nil) do
    Company.changeset(%Company{}, params) |> PaperTrail.insert(options)
  end

  defp update_company_with_version(company, params \\ @update_company_params, options \\ nil) do
    Company.changeset(company, params) |> PaperTrail.update(options)
  end

  defp create_person_with_version(company, params \\ @create_person_params, options \\ nil) do
    Person.changeset(%Person{}, Map.put(params, :company_id, company.id)) |> PaperTrail.insert(options)
  end

  defp serialize(model) do
    relationships = model.__struct__.__schema__(:associations)
    Map.drop(model, [:__struct__, :__meta__] ++ relationships)
  end
end
