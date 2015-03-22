path = require 'path'

trySave = (func) ->
  deferred = Promise.defer()

  try
    func()
    deferred.resolve()
  catch error
    if error.message.endsWith('is a directory')
      atom.notifications.addWarning("Unable to save file: #{error.message}")
    else if error.path?
      if error.code is 'EACCES'
        atom.notifications
          .addWarning("Unable to save file: Permission denied '#{error.path}'")
      else if error.code in ['EPERM', 'EBUSY', 'UNKNOWN', 'EEXIST']
        atom.notifications.addWarning("Unable to save file '#{error.path}'",
          detail: error.message)
      else if error.code is 'EROFS'
        atom.notifications.addWarning(
          "Unable to save file: Read-only file system '#{error.path}'")
    else if (errorMatch =
        /ENOTDIR, not a directory '([^']+)'/.exec(error.message))
      fileName = errorMatch[1]
      atom.notifications.addWarning("Unable to save file: A directory in the "+
        "path '#{fileName}' could not be written to")
    else
      throw error

  deferred.promise

getFullPath = (filePath) ->
  return filePath if path.isAbsolute(filePath)
  return path.join(atom.project.getPath(), filePath)

class Ex
  @singleton: =>
    @ex ||= new Ex

  @registerCommand: (name, func) =>
    @singleton()[name] = func

  quit: ->
    atom.workspace.getActivePane().destroyActiveItem()

  q: => @quit()

  tabedit: (range, args) ->
    args = args.trim()
    filePaths = args.split(' ')
    pane = atom.workspace.getActivePane()
    if filePaths? and filePaths.length > 0
      for file in filePaths
        do -> atom.workspace.openURIInPane file, pane
    else
      atom.workspace.openURIInPane('', pane)

  tabe: (args...) => @tabedit(args...)

  tabnew: (args...) => @tabedit(args...)

  tabclose: => @quit()

  tabc: => @tabclose()

  tabnext: ->
    pane = atom.workspace.getActivePane()
    pane.activateNextItem()

  tabn: => @tabnext()

  tabprevious: ->
    pane = atom.workspace.getActivePane()
    pane.activatePreviousItem()

  tabp: => @tabprevious()

  edit: (range, filePath) ->
    filePath = filePath.trim()
    if filePath.indexOf(' ') isnt -1
      throw new CommandError('Only one file name allowed')
    buffer = atom.workspace.getActiveEditor().buffer
    filePath = buffer.getPath() if filePath is ''
    buffer.setPath(getFullPath(filePath))
    buffer.load()

  e: (args...) => @edit(args...)

  enew: ->
    buffer = atom.workspace.getActiveEditor().buffer
    buffer.setPath(undefined)
    buffer.load()

  write: (range, filePath) ->
    filePath = filePath.trim()
    deferred = Promise.defer()

    pane = atom.workspace.getActivePane()
    editor = atom.workspace.getActiveEditor()
    if atom.workspace.getActiveTextEditor().getPath() isnt undefined
      if filePath.length > 0
        editorPath = editor.getPath()
        fullPath = getFullPath(filePath)
        trySave(-> editor.saveAs(fullPath))
          .then ->
            deferred.resolve()
        editor.buffer.setPath(editorPath)
      else
        trySave(-> editor.save())
          .then deferred.resolve
    else
      if filePath.length > 0
        fullPath = getFullPath(filePath)
        trySave(-> editor.saveAs(fullPath))
          .then deferred.resolve
      else
        fullPath = atom.showSaveDialogSync()
        if fullPath?
          trySave(-> editor.saveAs(fullPath))
            .then deferred.resolve

    deferred.promise

  w: (args...) =>
    @write(args...)

  wq: (args...) =>
    @write(args...).then => @quit()

  x: => @wq()

  wa: ->
    atom.workspace.saveAll()

  split: (range, args) ->
    args = args.trim()
    filePaths = args.split(' ')
    filePaths = undefined if filePaths.length is 1 and filePaths[0] is ''
    console.log filePaths, filePaths is ['']
    pane = atom.workspace.getActivePane()
    if filePaths? and filePaths.length > 0
      newPane = pane.splitUp()
      for file in filePaths
        do ->
          atom.workspace.openURIInPane file, newPane
    else
      pane.splitUp(copyActiveItem: true)

  sp: (args...) => @split(args...)

  vsplit: (range, args) ->
    args = args.trim()
    filePaths = args.split(' ')
    filePaths = undefined if filePaths.length is 1 and filePaths[0] is ''
    pane = atom.workspace.getActivePane()
    if filePaths? and filePaths.length > 0
      newPane = pane.splitLeft()
      for file in filePaths
        do ->
          atom.workspace.openURIInPane file, newPane
    else
      pane.splitLeft(copyActiveItem: true)

  vsp: (args...) => @vsplit(args...)

module.exports = Ex
