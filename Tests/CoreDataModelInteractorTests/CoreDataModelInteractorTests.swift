import XCTest
import CoreData
@testable import CoreDataModelInteractor

final class CoreDataModelInteractorTests: XCTestCase {

    private var storeUrl: URL!
    private let fileManager = FileManager.default
    private let sut = CoreDataModelInteractor()

    override func setUp() {
        super.setUp()
        prepareStoreUrl()
        setupOriginalModelStore()
    }

    override func tearDown() {
        super.tearDown()
        removeStore()
    }

    func testThat_WhenModelNotChanged_ThenInteractorResultCorrect() throws {
        let checkingResult = try sut.checkCompatibility(
            of: .originalModel,
            configuration: nil,
            withSQLiteStoreAt: storeUrl,
            options: nil
        )

        XCTAssertEqual(checkingResult, .compatible)
    }

    func testThat_WhenModelHasChangedToLightweightMigratable_ThenInteractorResultCorrect() throws {
        let checkingResult = try sut.checkCompatibility(
            of: .lightweightMigratableModel,
            configuration: nil,
            withSQLiteStoreAt: storeUrl,
            options: nil
        )

        XCTAssertEqual(checkingResult, .lightweightMigrationPossible)
    }

    func testThat_WhenModelHasChangedToIncompatible_ThenInteractorResultCorrect() throws {
        let checkingResult = try sut.checkCompatibility(
            of: .incompatibleModel,
            configuration: nil,
            withSQLiteStoreAt: storeUrl,
            options: nil
        )

        var error: NSError?
        if case .incompatible(let migrationError) = checkingResult {
            error = migrationError
        }

        XCTAssertNotNil(error)
    }

    // MARK: - Helpers

    private func setupOriginalModelStore() {
        let store = NSPersistentContainer(
            url: storeUrl,
            model: .originalModel
        )
        store.loadPersistentStores(completionHandler: { _, _ in })
    }

    private func prepareStoreUrl(){
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("db.sqlite")
        storeUrl = url
        removeStore()
    }

    private func removeStore() {
        guard fileManager.fileExists(atPath: storeUrl.path) else {
            return
        }
        do {
            try fileManager.removeItem(at: storeUrl)
        } catch {
            XCTFail("\(error)")
        }
    }
}

// MARK: - Test data

final class MockEntity: NSManagedObject {
    @NSManaged var value: NSNumber

    static var desctiption: NSEntityDescription {
        NSEntityDescription(
            objectType: self,
            properties: [
                NSAttributeDescription(
                    name: "value",
                    type: .integer64AttributeType,
                    isOptional: false
                )
            ]
        )
    }
}

/// Adds optional field to original model, lightweigh migration is supported
final class MockEntityLightweightMigratable: NSManagedObject {
    @NSManaged var value: NSNumber
    @NSManaged var value2: NSNumber?

    static var desctiption: NSEntityDescription {
        NSEntityDescription(
            oldObjectType: MockEntity.self,
            objectType: self,
            properties: [
                NSAttributeDescription(
                    name: "value",
                    type: .integer64AttributeType,
                    isOptional: false
                ),
                NSAttributeDescription(
                    name: "value2",
                    type: .integer64AttributeType,
                    isOptional: true
                )
            ]
        )
    }
}

/// Value type changed - incompatible change
final class MockEntityIncompatible: NSManagedObject {
    @NSManaged var value: NSString

    static var desctiption: NSEntityDescription {
        NSEntityDescription(
            oldObjectType: MockEntity.self,
            objectType: self,
            properties: [
                NSAttributeDescription(
                    name: "value",
                    type: .stringAttributeType,
                    isOptional: false
                )
            ]
        )
    }
}

extension NSManagedObjectModel {
    static var originalModel: NSManagedObjectModel {
        NSManagedObjectModel(entities: [MockEntity.desctiption])
    }

    static var lightweightMigratableModel: NSManagedObjectModel {
        NSManagedObjectModel(entities: [MockEntityLightweightMigratable.desctiption])
    }

    static var incompatibleModel: NSManagedObjectModel {
        NSManagedObjectModel(entities: [MockEntityIncompatible.desctiption])
    }
}

// MARK: - Helpers

private extension NSAttributeDescription {
    convenience init(
        name: String,
        type: NSAttributeType,
        isOptional: Bool
    ) {
        self.init()
        self.name = name
        self.attributeType = type
        self.isOptional = isOptional
    }
}

private extension NSEntityDescription {
    convenience init(
        oldObjectType: NSManagedObject.Type? = nil,
        objectType: NSManagedObject.Type,
        properties: [NSAttributeDescription]
    ) {
        self.init()
        self.name = String(describing: oldObjectType ?? objectType)
        self.managedObjectClassName = NSStringFromClass(objectType)
        self.properties = properties
    }
}

private extension NSManagedObjectModel {
    convenience init(entities: [NSEntityDescription]) {
        self.init()
        self.entities = entities
    }
}

private extension NSPersistentContainer {
    convenience init(
        url: URL,
        model: NSManagedObjectModel
    ) {
        self.init(
            name: "Container",
            managedObjectModel: model
        )
        let storeDescription = NSPersistentStoreDescription(
            url: url
        )
        // Setting journal mode off not to have extra files left on disk after tests
        storeDescription.setValue(
            "DELETE" as NSObject,
            forPragmaNamed: "journal_mode"
        )
        persistentStoreDescriptions = [storeDescription]
    }
}
