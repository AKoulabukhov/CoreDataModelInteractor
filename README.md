# CoreDataModelInteractor
![example workflow](https://github.com/AKoulabukhov/CoreDataModelInteractor/actions/workflows/swift.yml/badge.svg)

This package contains an utility class named CoreDataInteractor which has two missing CoreData functionalities:
- geting NSManagedObjectModel with which your store was open last time (in case of model changes in etween app versions)
- undestanding if the new model you bundled with you app can be used to open existing storage (including case where automatic lightweight migration should happen).

Usage is pretty simple:
```
let interactor = CoreDataModelInteractor()
let result = interactor.checkCompatibility(
    of: CURRENT_MODEL_IN_BUNDLE,
    configuration: nil,
    withSQLiteStoreAt: FILE_URL,
    options: nil
)
switch result {
case .compatible:
    // You are safe to load persistentStore
case .lightweightMigrationPossible:
    // Still safe but may take a time for a huge databases
case .incompatible(let error):
    // Don't try to open, you can delete old file if it's not needed, or preserve it and change store url for example till your next release with fix for this, may be you want to log an error somewhere
}
```

So instead of knowing result after we attempted to `loadPersistentStore` and trying to do this again - we can just check things in advance and do what we want.

The motivation and approach to solve this described in [article](https://todo.later)
