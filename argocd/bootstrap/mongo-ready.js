// Run by Mongo's startup probe. A primary must exist before the app starts.
try {
  rs.status()
} catch (error) {
  if (error.code !== 94 && error.codeName !== 'NotYetInitialized') {
    throw error
  }
  rs.initiate({ _id: 'overleaf', members: [{ _id: 0, host: '127.0.0.1:27017' }] })
}
if (!db.getSiblingDB('admin').hello().isWritablePrimary) {
  quit(1)
}
