# The sign-ins by brand and time, read by the team's panel for the accesses and the last
# sign-in of each contract (RN-19-091, D-626). Partial: only the sign-ins.
class AddSignInBrandIndexToAccessEvents < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :access_events, "(metadata->>'brand_id'), created_at", name: "index_access_events_on_sign_in_brand",
      where: "kind = 'auth' AND action = 'sign_in'", algorithm: :concurrently
  end
end
