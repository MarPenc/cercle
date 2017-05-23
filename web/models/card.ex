defmodule CercleApi.Card do
  @moduledoc """
  Card model.
  """
  use CercleApi.Web, :model

  @derive {Poison.Encoder, only: [
              :id, :name, :description, :status, :contact_ids, :user_id,
              :board_id, :board_column_id
            ]}

  schema "cards" do
    field :name, :string
    field :description, :string
    field :status, :integer, default: 0 #### 0 OPEN, 1 CLOSED
    field :contacts, {:array, :map}, virtual: true
    field :main_contact, {:map, CercleApi.Contact}, virtual: true
    field :contact_ids, {:array, :integer}
    belongs_to :user, CercleApi.User
    belongs_to :company, CercleApi.Company
    belongs_to :board, CercleApi.Board
    belongs_to :board_column, CercleApi.BoardColumn
    has_many :activities, CercleApi.Activity
    has_many :timeline_event, CercleApi.TimelineEvent,
      foreign_key: :card_id
    has_many :attachments, CercleApi.CardAttachment,
      foreign_key: :card_id, on_delete: :delete_all
    timestamps
  end

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, [:user_id, :company_id, :name, :status, :contact_ids, :board_id, :board_column_id, :description])
    |> put_change(:contact_ids, __MODULE__.build_contact_ids(params))
    |> validate_required([:contact_ids, :user_id, :company_id])
  end

  def build_contact_ids(params) do
    (params[:contact_ids] || params["contact_ids"] || [])
    |> Enum.filter(fn(x) -> !is_nil(x) end)
    |> Enum.uniq
  end

  def contacts(card) do
    card_contacts = from contact in CercleApi.Contact,
      where: contact.id in ^card.contact_ids
    CercleApi.Repo.all(card_contacts)
  end

  def get_main_contact(card) do
    case List.first(card.contact_ids || []) do
        nil -> nil
      contact_id ->
        CercleApi.Contact
        |> CercleApi.Repo.get(contact_id)
        |> CercleApi.Repo.preload([:organization])
    end
  end

  def preload_data(query \\ %CercleApi.Card{}) do
    comments_query = from c in CercleApi.TimelineEvent,
      order_by: [desc: c.inserted_at],
      preload: :user

    from q in query, preload: [
      :attachments,
      activities: [:contact, :user],
      timeline_event: ^comments_query
    ]
  end

  def preload_main_contact(cards) when is_list(cards) do
    Enum.map(cards, &preload_main_contact(&1))
  end

  def preload_main_contact(card \\ %CercleApi.Card{}) do
    Map.merge(card, %{main_contact: __MODULE__.get_main_contact(card)})
  end

  def preload_contacts(cards) when is_list(cards) do
    Enum.map(cards, &preload_contacts(&1))
  end

  def preload_contacts(card \\ %CercleApi.Card{}) do
    Map.merge(card, %{contacts: __MODULE__.contacts(card)})
  end
end

defimpl Poison.Encoder, for: CercleApi.Card do
  def encode(model, options) do
    model
    |> Map.take(
      [:id, :name, :description, :status, :contact_ids, :user_id, :board_id, :board_column_id]
    )
    |> Poison.Encoder.encode(options)
  end
end