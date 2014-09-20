# Overview
This document describes the resources that are accessible through the
BuildBotics API.

## Schema
All API access is over HTTP, and accessed from the root url
http://buildbotics.org/api/.  All data is sent and received as JSON.

## Data Types
### Notation
Types are denoted in this document by a keyword enclosed with ```<``` and
```>```.  For example: ```<name>``` or ```<integer>```.

Compound types are defined a dictionaries of keywords followed by their type
definition.  For example:

```coffeescript
{
  a: <string>
  b: <bool>
  c: <integer>
}
```

### Ranges
Type definitions may be followed by range definitions.  For example:

```none
(0,64)
```

In the case of a number, this indicates the numbers range is from 0 to 64
inclusive.  In the case of a string or array it refers to it's length.

### Comments
Type definitions may also include comments which follow a ```#``` sign.  For
example a complete type definition may appear as follows:

```coffeescript
{
  a: <string> (2,120) # A string, 0 to 64 characters long.
  b: <bool>
  c: <integer> (0,100) # An integer in the range 0 to 100 inclusive.
}
```


### Names
```none
<name>
```

A ```<name>``` is a ```string``` with length ```(2,64)``` and containing only
```[A-Za-z0-9_-]``` and not starting with '_' or '-'.

### Dates
```none
<date>
```

All timestamps are in [ISO 8601 format](http://en.wikipedia.org/wiki/ISO_8601):

```none
YYYY-MM-DDTHH:MM:SSZ
```

### Markdown
```none
<markdown>
```

Many text fields are in [Markdown format][markdown-syntax].
[GitHub flavored markdown][github-markdown] is also allowed.  These fields can
be no larger than 10KiB.

[markdown-syntax]: http://daringfireball.net/projects/markdown/syntax
[github-markdown]: https://help.github.com/articles/github-flavored-markdown

### Media types
```none
<media_type>
```

Media types, AKA mime types, are defined by [iana.org][media-types].

[media-types]: http://www.iana.org/assignments/media-types/media-types.xhtml

## Parameters
API methods may take optional parameters.  For GET requests parameters
may be specified either as part of the URL path or as HTTP query string
parameters.

For POST, PUT and DELETE request parameters not included in the URL path
should be endoded as JSON with Content-Type ```application/json```.

## Errors

## HTTP Verbs

## Authentication

## Pagination

# Users
## Model
A user profile is defined as follows:

```coffeescript
{
  owner: <name>
  avatar: <url>
  bio: <markdown>
  url: <url>
  stars: [<project_ref>...]
  following: [<name>...]
  followers: <integer>
}
```

A ```<project_ref>``` is defined as ```<name>/<name>``` where the first name
is the user and the second the project.

## Get user profile
```none
GET /users/{name}
```

### Example
```
GET /users/johndoe HTTP/1.1
```
```http
Status: 200 OK
Content-Type: application/json
```
```json
{
  owner: "johndoe",
  avatar: "http://example.com/images/johndoe.png",
  bio: "John is an avid builder...",
  url: "http://johndoe.com/",
  stars: ["janedoe/funproject", "jimmy/laser_bot"],
  following: ["janedoe", "buildbotics"],
  followers: 2
}
```

## Set user profile
```none
PUT /users/{name}
```

### Example
```http
PUT /users/johndoe HTTP/1.1
```
```json
{
  bio: "I like turtles.",
  url: "http://johndoe.com/",
}
```

```
Status: 200 OK
```

## Follow User
```none
PUT /users/{name}/follow
```

### Example
```
PUT /users/johndoe/follow HTTP/1.1
```

```
Status: 200 OK
```

## Unfollow User
```none
PUT /users/{name}/unfollow
```

### Example
```
PUT /users/johndoe/unfollow HTTP/1.1
```

```
Status: 200 OK
```

# Projects
## Model
```coffeescript
{
  name: <name>
  creation: <date>
  url: <url>
  license: <string> (2,120)
  owner: <name>
  parent: <project_ref>
  published: <bool>
  text: <markdown>
  tags: [<tag>...] (0,64)
  files: [<file>..] (0,64)
  steps: [<step>...] (0,64)
  comment: [<comment>...] (0,4096)
  stars: <integer>
  latest_stars: [<name>...] (0,100)
}
```

## Create project
## Update project
## Star project
## Unstar project
## Tag project
## Untag project

# Comments
## Model
```coffeescript
{
  id: <integer>
  owner: <name>
  creation: <date>
  ref: <integer> # A reference to a previous comment.
  text: <markdown>
}
```

# Steps
## Model
```coffeescript
{
  title: <string> (0,120)
  text: <markdown>
  media: [<file>...] (0,64)
  comments: [<comment>...]
}
```

# Files
## Model
```coffeescript
{
  type: <media_type>
  creation: <date>
  ref: <file_ref>
  downloads: <integer>
}
```

A ```<file_ref>``` is an SHA256 hash of the file contents in
[RFC 4648][rfc4648] base 64 format for a total of 43 bytes.  For example:

```none
VvOv3aKEySQCe8K3/JjoLiYmDPXb7/2W7FjdoTzZ2qk
```

[rfc4648]: http://tools.ietf.org/html/rfc4648

# Events

# Search

# Tags
A tag may be any ```<name>```.

# Licenses
## Model
```coffeescript
{
  name: <string> (2,120)
  url: <url>
  brief: <markdown>
  text: <markdown>
  sharable: <bool>
  comercial_use: <bool>
  attribution: <bool>
}
```

