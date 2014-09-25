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

### Email Addresses
Email addresss are formated as described in
[RFC 2822 Section 3.4.1][rfc2822-3.4.1].

[rfc2822-3.4.1]: http://tools.ietf.org/html/rfc2822#section-3.4.1

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
## Profile Model
User profiles are defined as follows:

```coffeescript
<profile> = {
  owner: <name>
  fullname: <string> (0,120)
  avatar: <url>
  bio: <markdown>
  url: <url>
  stars: [<project_ref>...] (0,4096)
  following: [<name>...] (0,4096)
  followers: <integer>
}
```

A ```<project_ref>``` is defined as ```<name>/<name>``` where the first name
is the user and the second the project.
For example, ```jimmy/fun_with_lasers```.

## Get user profile
```none
GET /users/{name}
```

### Example
#### Request
```
GET /users/johndoe HTTP/1.1
```

#### Response
```http
Status: 200 OK
Content-Type: application/json
```
```json
{
  owner: "johndoe",
  avatar: "http://example.com/~johndoe/images/johndoe.png",
  bio: "John is an avid builder...",
  url: "http://example.com/~johndoe/",
  stars: ["janedoe/funproject", "jimmy/laser_bot"],
  following: ["janedoe", "buildbotics"],
  followers: 2
}
```

## Set user profile data
```none
PUT /users/{name}
```

### Parameters
Name | Type | Description
--|--|--
**avatar** | ```<url>``` | URL to user's avatar.
**bio** | ```<markdown>``` | User's public biography.
**url** | ```<url>``` | Link to user's home page.

Other profile parameters cannot be changed with this API call.


### Example
```http
PUT /users/johndoe HTTP/1.1
```
```json
{
  bio: "I like turtles.",
  url: "http://example.com/~johndoe/",
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

# Settings
## Settings Model
```coffeescript
<settings> = {
  email: [<email>...] (0,8)
  notifications: <notifications>
}
```

```coffeescript
<email> = {
  address: <email_address>
  verified: <bool>
  primary: <bool>
}
```

```coffeescript
<notifications> = {
  enabled: <bool>
  project_comments: <bool>
  project_starred: <bool>
  when_followed: <bool>
  comment_referenced: <bool>
  stared_project_updates: <bool>
  stared_project_comments: <bool>
}
```

## Get email addresses
```none
GET /emails
```

## Add email address
```none
PUT /emails/{email_address}
```

### Parameters
Name | Type | Description
--|--|--
**primary** | ```<bool>``` | Make this the primary email address.


## Remove email address
```none
DELETE /emails/{email_address}
```

## Get notification settings
```none
GET /notifications
```

## Set notification settings
```none
PUT /notifications
```

### Parameters
<table>
  <tr>
    <th>Name</th><th>Type</th><th>Description</th>
  </tr>
  <tr>
    <td>**enabled**</td><td>```<bool>```</td>
    <td>Enable or disable all notifications.</td>
  </tr>
  <tr>
    <td>**project_comments**</td><td>```<bool>```</td>
    <td>Comments on the owner's project.</td>
  </tr>
  <tr>
    <td>**project_starred**</td><td>```<bool>```</td>
    <td>Stars on the owner's project.</td>
  </tr>
  <tr>
    <td>**when_followed**</td><td>```<bool>```</td>
    <td>Someone followed the owner.</td>
  </tr>
  <tr>
    <td>**comment_referenced**</td><td>```<bool>```</td>
    <td>The owner's comment was referenced.</td>
  </tr>
  <tr>
    <td>**stared_project_updates**</td><td>```<bool>```</td>
    <td>A project the owner starred was updated.</td>
  </tr>
  <tr>
    <td>**stared_project_comments**</td><td>```<bool>```</td>
    <td>A project the owner starred was commented.</td>
  </tr>
</table>


# Projects
## Project Model
```coffeescript
<project> = {
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
## Comment Model
```coffeescript
<comment> = {
  id: <integer>
  owner: <name>
  creation: <date>
  ref: <integer> # A reference to a previous comment.
  text: <markdown>
}
```

# Steps
## Step Model
```coffeescript
<step> = {
  title: <string> (0,120)
  text: <markdown>
  media: [<file>...] (0,64)
  comments: [<comment>...]
}
```

# Files
## File Model
```coffeescript
<file> = {
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
## Event Model
```coffeescript
<event> = {
  type: <string>
  timestamp: <date>
  url: <url>
  summary: <markdown>
}
```

# Search
## Result Model
```coffeescript
<result> = {
  url: <url>
  summary: <markdown>
}
```

# Tags
## Get a list of tags
```none
GET /tags
```

## Create a new tag
```none
PUT /tags
```

### Parameters
Name | Type | Description
--|--|--
**tag** | ```<name>``` | **Required**. The tag name.

# Licenses
## License Model
```coffeescript
<license> = {
  name: <string> (2,120)
  url: <url>
  brief: <markdown>
  text: <markdown>
  sharable: <bool>
  comercial_use: <bool>
  attribution: <bool>
}
```

## Get a list of licenses
```none
GET /licenses
```

## Create a new license
```none
PUT /licenses
```

### Parameters
Name | Type | Description
--|--|--
**license** | ```<license>``` | **Required**. The license record.
