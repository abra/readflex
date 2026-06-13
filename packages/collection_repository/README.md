# collection_repository

Repository for manual Library collections and protected built-in collection
memberships.

## Public API

| Method | Purpose |
|--------|---------|
| `getCollections()` | Returns user-created collections with source counts |
| `getCollectionSourceIds()` | Returns source ids grouped by collection id |
| `getFavouriteSourceIds()` | Returns source ids in the protected favourites collection |
| `createCollection(name)` | Creates an empty manual collection |
| `renameCollection(...)` | Renames a manual collection |
| `deleteCollection(id)` | Deletes a manual collection and its memberships |
| `updateCollection(...)` | Renames and/or removes sources from a manual collection |
| `addSourcesToCollection(...)` | Adds sources to a manual collection |
| `addSourcesToFavourites(...)` | Adds sources to the built-in favourites collection |
| `removeSourcesFromCollection(...)` | Removes sources from a manual collection |
| `removeSourcesFromFavourites(...)` | Removes sources from favourites |
| `createCollectionWithSources(...)` | Creates a collection and fills it in one transaction |
| `removeSourcesFromCollections(sourceIds)` | Removes dangling memberships after source deletion |

## Collection Types

The repository persists manual collections plus the protected favourites
membership. Smart collections, such as author or site/domain groupings, are
computed by the Library feature from source metadata and are not stored here.

`favouritesCollectionId` is protected: manual collection APIs reject it so the
built-in collection cannot be renamed or deleted accidentally.

## Dependencies

- `domain_models` - `LibraryCollection` and `StorageException`
- `local_storage` - Drift database and `CollectionsDao`
- `uuid`

## Where It Fits

`routing.dart` injects this repository into `LibraryScreen`. The Library feature
uses it to manage manual collections and favourites while keeping smart
collection derivation in UI/domain state.
