import Foundation
import CoreData
import SQLite3

public enum CoreDataModelInteractorError: Error {
    case openDatabaseError(code: Int32)
    case prepareStatementError(code: Int32)
    case modelQueryError(code: Int32)
    case modelBlobNotFound
    case decompressionFailed(underlyingError: Error)
    case decodingFailed(underlyingError: Error)
    case decodedDataIsEmpty
    case metadataFetchError(underlyingError: Error)
}

public enum CodeDataModelCompatibility: Equatable {
    case compatible
    case lightweightMigrationPossible
    // Error contains useful information about incompatibility
    case incompatible(error: NSError)
}

public protocol CoreDataModelInteractorProtocol: AnyObject {
    func getManagedObjectModel(fromSQLiteStoreAt url: URL) throws -> NSManagedObjectModel
    func checkCompatibility(
        of model: NSManagedObjectModel,
        configuration: String?,
        withSQLiteStoreAt url: URL,
        options: [AnyHashable : Any]?
    ) throws -> CodeDataModelCompatibility
}

/// Default arguments support
public extension CoreDataModelInteractorProtocol {
    func checkCompatibility(
        of model: NSManagedObjectModel,
        configuration: String? = nil,
        withSQLiteStoreAt url: URL,
        options: [AnyHashable : Any]? = nil
    ) throws -> CodeDataModelCompatibility {
        try checkCompatibility(
            of: model,
            configuration: configuration,
            withSQLiteStoreAt: url,
            options: options
        )
    }
}

public final class CoreDataModelInteractor: CoreDataModelInteractorProtocol {
    private typealias Error = CoreDataModelInteractorError

    public init() { }

    // MARK: - CoreDataModelInteractorProtocol

    /// Based on -[NSSQLiteConnection fetchCachedModel:] code from CoreData.framework
    /// Please fill in feature requests to Apple to make this functionality public
    /// along with metadataForPersistentStore:
    public func getManagedObjectModel(fromSQLiteStoreAt url: URL) throws -> NSManagedObjectModel {
        let db = try openDatabase(at: url)
        let modelData = try getModelCacheData(from: db)
        closeDatabase(db)
        let model = try decodeModel(from: modelData)
        return model
    }

    public func checkCompatibility(
        of model: NSManagedObjectModel,
        configuration: String?,
        withSQLiteStoreAt url: URL,
        options: [AnyHashable : Any]?
    ) throws -> CodeDataModelCompatibility {
        let storeMetadata: [String : Any]
        do {
            storeMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: url,
                options: options
            )
        } catch {
            throw Error.metadataFetchError(underlyingError: error)
        }
        let isFullyCompatible = model.isConfiguration(
            withName: configuration,
            compatibleWithStoreMetadata: storeMetadata
        )
        if isFullyCompatible {
            return .compatible
        }
        let cachedModel = try getManagedObjectModel(fromSQLiteStoreAt: url)
        do {
            _ = try NSMappingModel.inferredMappingModel(
                forSourceModel: cachedModel,
                destinationModel: model
            )
            return .lightweightMigrationPossible
        } catch {
            return .incompatible(error: error as NSError)
        }
    }

    // MARK: - Private

    private func openDatabase(at url: URL) throws -> OpaquePointer {
        var db: OpaquePointer?
        let result = sqlite3_open(url.path, &db)
        if result == SQLITE_OK, let pointer = db {
            return pointer
        } else {
            throw Error.openDatabaseError(
                code: result
            )
        }
    }

    private func closeDatabase(_ db: OpaquePointer) {
        sqlite3_close(db)
    }

    private func getModelCacheData(from db: OpaquePointer) throws -> Data {
        var queryStatement: OpaquePointer?
        var result = sqlite3_prepare_v2(
            db,
            "SELECT Z_CONTENT FROM Z_MODELCACHE;",
            -1,
            &queryStatement,
            nil
        )
        guard result == SQLITE_OK else {
            throw Error.prepareStatementError(code: result)
        }
        result = sqlite3_step(queryStatement)
        guard result == SQLITE_ROW else {
            throw Error.modelQueryError(code: result)
        }
        guard let blob = sqlite3_column_blob(queryStatement, 0) else {
            throw Error.modelBlobNotFound
        }
        let count = sqlite3_column_bytes(queryStatement, 0)
        let data = Data(
            bytes: blob,
            count: numericCast(count)
        )
        sqlite3_finalize(queryStatement)
        return data
    }

    private func decodeModel(from data: Data) throws -> NSManagedObjectModel {
        let decompressedData: Data
        do {
            decompressedData = try (data as NSData).decompressed(using: .zlib) as Data
        } catch {
            throw Error.decompressionFailed(underlyingError: error)
        }
        let decodedModel: NSManagedObjectModel?
        do {
            decodedModel = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSManagedObjectModel.self,
                from: decompressedData
            )
        } catch {
            throw Error.decodingFailed(underlyingError: error)
        }
        guard let decodedModel = decodedModel else {
            throw Error.decodedDataIsEmpty
        }
        return decodedModel
        
    }
}
