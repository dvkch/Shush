# Shush

Shush is your favorite librarian. Its goal is to make sure your simple data persistence needs are met.

Have you ever had a couple user preferences you'd like to sync without having to think (I know, I know) too much ? What about an array of the last 30 queries your user ran in your app ? Or some lightweight user generated data that you want persisted and synchronized using iCloud ?

Those are all handled easily, while trying its best to stay out of your way.

### Example

Let's imagine you have a simple browser app where your user can save favorites and archive pages.

> [!NOTE]
> All following property wrappers and constructs have variants depending on your need to use iCloud sync or not. To use it you need to already have setup your iCloud and ubiquitous containers entitlements, see [the official documentation](https://developer.apple.com/documentation/xcode/configuring-icloud-services)

##### Keeping track of preferences

```swift
import Shush

extension NSNotification.Name {
    static let settingsChanged = NSNotification.Name("settings_changed")
}

struct Preferences {
    let shared = Preferences()

    @ShushValue(key: "using_dark_theme", defaultValue: false, notification: .settingsChanged)
    var usingDarkTheme: Bool
}
```

That's it! You now have access to `Preferences.shared.usingDarkTheme` across your whole app and will be notified when it changes, either from inside your app, of from another device.

##### Krep track of favorites

Let's create our struct

```swift
struct WebFavorite: Codable, Identifiable {
    let date: Date
    let url: URL

    var id: String { url.standardized.absoluteString }
}
```

Now let's persist it!

```swift
extension NSNotification.Name {
    static let favoritesChanged = NSNotification.Name("favorites_changed")
}

struct Preferences {
    ...
    
    @PrefArray(prefix: "favorite", sortedBy: \.date, order: .desc, notification: .favoritesChanged)
    var favorites: [WebFavorite]
    
    func insertFavorite(_ favorite: WebFavorite) {
        _favorites.insert(favorite)
    }
}
```

As above, you'll now be alerted each time an item changes, from a device or another. This will create multiple `UserDefaults` and `NSUbiquitousKeyValueStore` keys, each associated to one element of your array, allowing for conflict-free updates on all devices.

##### Saving archives

Let's imagine a simple archive structure. The `archiveData` attribute could for instance contain a PDF version of the archived page.

```swift
struct WebArchive {
    let date: Date
    let url: URL
    let archiveData: Data
}
```

How do we synchronize this ? You'll need to conform to `Persistable`. In the spirit of avoiding unnecessary decoding, you'll also need a secondary struct that holds your archive metadata. Here is our updated code :

```swift
struct WebArchiveMetadata {
    let date: Date
    let url: URL
}
extension WebArchiveMetadata: PersistablePartial {}

extension WebArchive: Persistable {
    static var fileExtension: String {
        return "webarchive"
    }

    var partialRepresentation: WebArchiveMetadata {
        return .init(date: date, url: url)
    }
    
    static func decodePersisted(_ data: Data) throws -> WebArchive {
        return try JSONDecoder().decode(WebArchive.self, from: data)
    }
    
    static func decodePersistedPartially(_ data: Data) throws -> WebArchiveMetadata {
        return try JSONDecoder().decode(WebArchiveMetadata.self, from: data)
    }

    static func encodePersisted(_ data: WebArchive) throws -> Data {
        return try JSONEncoder().encode(data)
    }
}

extension WebArchive: PersistableIdentifiable {
    static func suggestedFilename(for persistable: WebArchive) -> String {
        return "Archive \(date)"
    }
}
```

And now let's persist it!

```swift
import Shush

extension NSNotification.Name {
    static let archivesChanged = NSNotification.Name("archives_changed")
}

struct Preferences {
    ...
    let archives: ShushFiles<WebArchive, Date> = .init(
        ubiquityContainer: "iCloud.com.example.App",
        sortedBy: \.partial.date, order: .desc,
        notification: .archivesChanged
    )
}
```

You can now easily:

```swift

// List your files
Preferences.shared.archives.files

// Insert a file
let archive = ...
let archiveFile = Preferences.shared.archives.insert(archive)

// Read the full content of a file
let fullContent = Preferences.shared.archives.read(archiveFile)

// Delete a file
Preferences.shared.files.remove(archiveFile)
```

## License

Use it as you like in every project you want, redistribute as much as you want, preferably with mentions of my name when it applies and don't blame me if it breaks :)

-- dvkch
 
