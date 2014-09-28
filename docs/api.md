# Overview
This document describes the resources that are accessible through the
BuildBotics API.

This section describes the details of the protocol and the following sections
describe individual data models and their API calls.

## Schema
All API access is over HTTP, and accessed from the root URL
http://buildbotics.org/api/.  All data is sent and received as JSON.

In the API docmentation the root URL and HTTP version are left off.  So for
example:

```none
PUT /users/{name}/follow
```

is actually:

```http
PUT http://buildbotics.org/api/users/{name}/follow HTTP/1.1
```

## Parameters
API methods may take optional parameters.  These request parameters may be
specified as follows:

 1. URL parameters as part of the URL path.
 2. As HTTP [query string parameters][rfc3986-3.4].
 3. As JSON encoded data.

[rfc3986-3.4]: http://tools.ietf.org/html/rfc3986#section-3.4

URL parameters are specified using curly braces.  For example:

```none
PUT /users/{name}/follow
```

In the above case ```{name}``` is a URL parameter.

For POST, PUT and DELETE request parameters not included in the URL path
should be encoded as JSON with Content-Type ```application/json```.


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

### Model Comments
Type definitions may also include comments which follow a ```#``` sign.  For
example a complete type definition may appear as follows:

```coffeescript
{
  a: <string> (2,120) # A string, 2 to 120 characters long.
  b: <bool>
  c: <integer> (0,100) # An integer in the range 0 to 100 inclusive.
}
```


### Names
```none
<name> = <string> (2,64) # Matching regex [A-Za-z0-9][A-Za-z0-9_-]{1,63}
```

A ```<name>``` is a ```<string>``` with length ```(2,64)``` containing only
```[A-Za-z0-9_-]``` and not starting with '_' or '-'.

### Dates
```none
<date> = <string> # In ISO 8601 format
```

All dates and times are in
[ISO 8601 format](http://en.wikipedia.org/wiki/ISO_8601)
:```YYYY-MM-DDTHH:MM:SSZ```

### Email Addresses
```none
<email_address> = <string> # In RFC 28822 Section 3.4.1 format
```

Email addressees are formatted as described in
[RFC 2822 Section 3.4.1][rfc2822-3.4.1].

[rfc2822-3.4.1]: http://tools.ietf.org/html/rfc2822#section-3.4.1

### Markdown
```none
<markdown> = <string> (0,10KiB) # In Markdown format
```

Many text fields are in [Markdown format][markdown-syntax].
[GitHub flavored markdown][github-markdown] is also allowed.

[markdown-syntax]: http://daringfireball.net/projects/markdown/syntax
[github-markdown]: https://help.github.com/articles/github-flavored-markdown

### Media types
```none
<media_type> = <string> # As defined by iana.org
```

Media types, AKA mime types, are defined by [iana.org][media-types].

[media-types]: http://www.iana.org/assignments/media-types/media-types.xhtml

## Errors

In case of error, HTTP status codes are returned.  These codes are defined by
[RFC 2068 Section 10][rfc2068-sec10] and [RFC 4918 Section 11][rfc4918-sec11].

Possible errors include:

- ```400 Bad Request``` in case of malformed JSON input.
- ```403 Forbidden``` or ```404 Not Found``` in case of an authorization error.
- ```404 Not Found``` in case a request resource does not exist.
- ```405 Method Not Allowed``` in case of an invalid or unsupported API call.
- ```422 Unprocessable Entity``` in case of semantically incorrect input.
- ```503 Service Unavailable``` rate limit exceeded.

[rfc2068-sec10]: https://tools.ietf.org/html/rfc2068#section-10
[rfc4918-sec11]: https://tools.ietf.org/html/rfc4918#section-11

Other HTTP error codes may be returned where appropriate.

More details about an error may be returned as JSON data defined as follows:

```coffeescript
<errors> = [<error>...]

<error> = {
  message: <string>
  code: <name>
  field: <name> # The particular field for which there was an error.
}
```

## Error Codes

Error Code | Description
:----------|--------------------------------------------------------------------
required   | The specified field is not optional.
invalid    | The specified field is invalid.
exists     | The resource already exists and cannot be created.

## HTTP Verbs

This API uses the following HTTP Verbs as described below.

- ```GET```    - Get a resource or list of resources.
- ```POST```   - Create a new resource for which the name is not yet known.
- ```PUT```    - Create or modify an resource for which the name is known.
- ```DELETE``` - Delete an existing resource by name.

## Authentication

Authentication is provided by third-party providers exclusively.  These are as
follows:

Provider | Type
:--|--|--
Google+  | [OAuth 2.0 API][google-oauth2]
Facebook | [OAuth 2.0 API][facebook-oauth2]
GitHub   | [OAuth 2.0 API][github-oauth2]
Twitter  | [OAuth 1.0a API][twitter-oauth1a]

[google-oauth2]:   https://developers.google.com/+/api/oauth
[facebook-oauth2]: https://developers.facebook.com/docs/reference/dialogs/oauth/
[github-oauth2]:   https://developer.github.com/v3/oauth/
[twitter-oauth1a]: https://dev.twitter.com/oauth

One or more of these third-parties may be used to associate logins and
verified email addresses with the BuildBotics API.

## Pagination
Request which return multiple items are paginated.  By default 20 items are
returned per call.  Each item is supplied with an ```offset``` key which
tells where it is in the stream.

### Parameters
Name | Type | Description
:--|--|--
**limit** | ```<integer>``` (1,100) | **Default 30**. Items per page.
**next** | ```<string>``` | Offset of the item just before the requested page.
**prev** | ```<string>``` | Offset of the item just after the requested page.

Either **next** or **prev** may be provided but not both.  Both parameters
should be copied from the **offset** field of a previous request.

## Rate Limiting
Rate limits are as follows:

User | Max Requests in <br/> Past 5 Minutes
:--|--
Unauthenticated | 50
Authenticated   | 200

If you exceed the rate limit ```503 Service Unavailable``` will be returned.

# Users
## Profile Model
User profiles are defined as follows:

```coffeescript
<profile> = {
  owner: <name>
  joined: <date>
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
  joined: "2014-09-27T07:15:05Z",
  fullname: "John Doe",
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
:--|--|--
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
:--|--|--
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
  owner: <name>
  creation: <date>
  modified: <date>
  parent: <project_ref>
  published: <bool>
  url: <url>
  license: <string> (2,120)
  brief: <markdown> (0,200)
  description: <markdown>
  video: <url>
  stars: <integer>
  latest_stars: [<name>...] (0,100)
  tags: [<tag>...] (0,64)
  comment: [<comment>...] (0,4096)
  steps: [<step>...] (0,64)
  files: [<file>..] (0,64)
}
```

## Create or update a project
```none
PUT /users/{user}/projects/{project}
```

### Parameters
Name | Type | Description
:--|--|--
**url** | ```<url>``` | A URL to more information about the project.
**license** | ```<string>``` | One of the available license names.
**published** | ```<bool>``` | True to publish the project publicly.
**description** | ```<markdown>``` | The project description.
**video** | ```<url>``` | The project video.

Only approved video URLs are allowed.

## Rename a project
```none
PUT /users/{user}/projects/{project}
```

### Parameters
Name | Type | Description
:--|--|--
**name** | ```<name>``` | The new project name.

## Duplicate a project
```none
PUT /users/{user}/projects/{project}
```

### Parameters
Name | Type | Description
:--|--|--
**ref** | ```<project_ref>``` | A reference to the parent project.

## Star project
```none
PUT /users/{user}/projects/{project}/star
```

## Unstar project
```none
DELETE /users/{user}/projects/{project}/star
```

## Tag project
```none
PUT /users/{user}/projects/{project}/tags/{tag}
```

## Untag project
```none
DELETE /users/{user}/projects/{project}/tags/{tag}
```

# Comments
## Comment Model
```coffeescript
<comment> = {
  id: <integer>
  owner: <name>
  creation: <date>
  ref: <integer>   # A reference to a previous comment.
  text: <markdown>
  deleted: <bool>  # True if the comment was marked as deleted.
}
```

## Post a comment
```none
POST /users/{user}/projects/{project}/comments
POST /users/{user}/projects/{project}/steps/{step}/comments
```

### Parameters
Name | Type | Description
:--|--|--
**ref** | ```<integer>``` | A reference to an existing comment.
**text** | ```<markdown>``` | **Required**.  The comment text.

## Update a comment
```none
PUT /users/{user}/projects/{project}/comments/{comment}
PUT /users/{user}/projects/{project}/steps/{step}/comments/{comment}
```

### Parameters
Name | Type | Description
:--|--|--
**text** | ```<markdown>``` | The updated comment text.
**delete** | ```<bool>``` | True if the comment should be marked deleted.

# Steps
## Step Model
```coffeescript
<step> = {
  name: <name>
  description: <markdown>
  video: <url>
  comments: [<comment>...]
  files: [<string>...] (0,8)
}
```

## Create or update a step
```none
PUT /users/{user}/projects/{project}/steps/{step}
```

### Parameters
Name | Type | Description
:--|--|--
**description** | ```<markdown>``` | The step description.
**video** | ```<url>``` | The step video.

Only approved video URLs are allowed.

## Rename a step
```none
PUT /users/{user}/projects/{project}/steps/{step}
```

### Parameters
Name | Type | Description
:--|--|--
**name** | ```<name>``` | The new step name.

## Reorder a step
```none
PUT /users/{user}/projects/{project}/steps/{step}
```

### Parameters
Name | Type | Description
:--|--|--
**position** | ```<integer>``` | **Required**.  New position of the step.

## Delete a step
```none
DELETE /users/{user}/projects/{project}/steps/{step}
```

# Files
## File Model
```coffeescript
<file> = {
  name: <string> (1,256)
  type: <media_type>
  creation: <date>
  ref: <file_ref>
  downloads: <integer>
  caption: <string> (0,120)
  display: <bool>   # Images only
}
```

A ```<file_ref>``` is an SHA256 hash of the file contents in
[RFC 4648][rfc4648] base 64 format for a total of 43 bytes.  For example:

```none
VvOv3aKEySQCe8K3/JjoLiYmDPXb7/2W7FjdoTzZ2qk
```

[rfc4648]: http://tools.ietf.org/html/rfc4648

## Upload a file
```none
PUT /users/{user}/projects/{project}/files/{file}
PUT /users/{user}/machines/{machine}/files/{file}
```

## Update a file
```none
PUT /users/{user}/projects/{project}/files/{file}
PUT /users/{user}/machines/{machine}/files/{file}
```

Name | Type | Description
:--|--|--
**caption** | ```<integer>``` | The file caption.
**display** | ```<bool>``` | **Images only***.  The file caption.

## Reorder a file
```none
PUT /users/{user}/projects/{project}/files/{file}
PUT /users/{user}/machines/{machine}/files/{file}
```

Name | Type | Description
:--|--|--
**position** | ```<integer>``` | The new file position.

## Rename a file
```none
PUT /users/{user}/projects/{project}/files/{file}
PUT /users/{user}/machines/{machine}/files/{file}
```

Name | Type | Description
:--|--|--
**name** | ```<name>``` | The new file name.

## Delete a file
```none
DELETE /users/{user}/projects/{project}/files/{file}
DELETE /users/{user}/machines/{machine}/files/{file}
```

# Events
## Event Model
```coffeescript
<event> = {
  type: <string>
  timestamp: <date>
  owner: <name>
  target: <name>
  url: <url>
  summary: <markdown>
  offset: <string>
}
```

## Event Types
Name | Description
:--|--
**publish** | Someone published a new project.
**update** | Someone updated a project.
**tag** | Someone tagged a project.
**untag** | Someone untagged a project.
**comment** | Someone posted a comment.
**star** | Someone starred a project.
**follow** | Someone followed a user.
**unfollow** | Someone unfollowed a user.

## Event Parameters
Name | Type | Description
:--|--|--
**limit**  | ```<integer>``` | Limit the number of events returned.
**before** | ```<string>```  | Return events before this offset.
**after**  | ```<string>```  | Return events after this offset.

## View your events
```none
GET /events
```

## View user events
```none
GET /users/{user}
```

## View project events
```none
GET /users/{user}/projects/{project}
```

# Tags
## Get a list of tags
```none
GET /tags
```

## Create a new tag
```none
PUT /tags/{tag}
```

## Delete a tag
```none
DELETE /tags/{tag}
```

# Licenses
## License Model
```coffeescript
<license> = {
  name: <string> (2,120)
  url: <url>
  brief: <markdown> (0,200)
  text: <markdown>
  shareable: <bool>
  commercial_use: <bool>
  attribution: <bool>
}
```

## Get a list of licenses
```none
GET /licenses
```

## Create or update a license
```none
PUT /licenses/{license}
```

### Parameters
Name | Type | Description
:--|--|--
**url** | <url> | URL to license.
**brief** | <markdown> | Brief description of license.
**text** | <markdown> | Full text of license.
**shareable** | <bool> | Does this license allow sharing.
**commercial_use** | <bool> | Does this license allow commercial use.
**attribution** | <bool> | Does this license require attribution.

## Delete a license
```none
DELETE /licenses/{license}
```

# Machines
## Machine Model
```coffeescript
<machine> = {
  name: <name>
  type: <name>            # "cnc", "3d_printer", "laser", "plasma", "lathe"
  owner: <name>
  creation: <date>
  modified: <date>
  parent: <project_ref>
  published: <bool>
  url: <url>
  brief: <markdown> (0,200)
  description: <markdown>
  units: <string>         # "imperial" or "metric"
  rotation: <string>      # "degrees" or "radians"
  max_rpm: <real>         # Maximum rotational speed
  spin_up: <real>         # Rate of spin up in RPM/sec
  axes: [<axis>...] (1,9)
  files: [<file>..] (0,64)
}
```
```coffeescript
<axis> = {
  name: <string> (1,1)  # X, Y, Z, A, B, C, U, V, W
  min: <real>           # in, mm, deg, radians
  max: <real>           # in, mm, deg, radians
  step: <real>          # in or mm
  rapid_feed: <real>    # in/sec or mm/sec
  cutting_feed: <real>  # in/sec or mm/sec
  ramp_up: <real>       # in/sec/sec or mm/sec/sec
  ramp_down: <real>     # in/sec/sec or mm/sec/sec
}
```

## Get a list of machines
```none
GET /users/{user}/machines
```

## Create or update a machine
```none
PUT /users/{user}/machines/{machine}
```

### Parameters
Name | Type | Description
:--|--|--
**url** | ```<url>``` | URL to page about machine.
**brief** | ```<markdown>``` | A brief description of the machine.
**description** | ```<markdown>``` | A full description of the machine.
**units** | ```<string>``` | ```"imperial"``` or ```"metric"```.
**rotation** | ```<string>``` | ```"degrees"``` or ```"radians"```.

## Copy a machine
```none
PUT /users/{user}/machines/{machine}
```

### Parameters
Name | Type | Description
:--|--|--
**ref** | ```<string>``` | A machine reference: ```{user}/{machine}```.

## Rename a machine
```none
PUT /users/{user}/machines/{machine}
```
### Parameters
Name | Type | Description
:--|--|--
**name** | ```<name>``` | New machine name.


## Delete a machine
```none
DELETE /users/{user}/machines/{machine}
```

## Create or update an Axis
```none
PUT /users/{user}/machines/{machine}/axes/{axis}
```
### Parameters
Name | Type | Description
:--|--|--
**min**           | ```<real>``` | Minimum position of axis.
**max**           | ```<real>``` | Maximum position of axis.
**step**          | ```<real>``` | Minimum step.
**rapid_speed**   | ```<real>``` | Fastest rapid speed.
**cutting_speed** | ```<real>``` | Fastest cutting speed.
**ramp_up**       | ```<real>``` | Ramp up rate.
**ramp_down**     | ```<real>``` | Ramp down rate.

## Delete an Axis
```none
DELETE /users/{user}/machines/{machine}/axes/{axis}
```

# Tools
## Tool Model
```coffeescript
<tool> = {
  name: <name>
  owner: <name>
  creation: <date>
  modified: <date>
  parent: <project_ref>
  published: <bool>
  type: <string>        # "cylindrical", "conical", "ballnose",
                        # "spheroid" or "composite"
  url: <url>
  brief: <markdown> (0,200)
  description: <markdown>
  units: <string>       # "imperial" or "metric"
  length: <real>        # Length of cutter
  diameter: <real>      # Diameter a base
  nose_diameter: <real> # Diameter a tip
  flutes: <integer>     # Number of flutes
  flute_angle: <real>   # Rake angle of the flute
  lead_angle: <real>    # Angle between cutting edge & perpendicular plane
  max_doc: <real>       # Maximum depth of cut
  max_woc: <real>       # Maximum width of cut
  max_rpm: <real>       # Maximum rotational speed
  max_feed: <real>      # Maximum feed rate
  children: [{          # Composite tools only
    offset: <real>
    tool: <tool>
  }...]
}
```

## Get a list of tools
```none
GET /users/{user}/tools
```

## Create or update a tool
```none
PUT /users/{user}/tools/{tool}
PUT /users/{user}/tools/{tool}/children/{tool}
```

### Parameters
Name | Type | Description
:--|--|--
**type** | ```<string>``` | Tool type.
**url** | ```<url>``` | URL to webpage about tool.
**brief** | ```<markdown>``` (0,200) | A brief description of the tool.
**description** | ```<markdown>``` | A full description of the tool.
**units** | ```<string>``` | "imperial" or "metric"
**length** | ```<real>``` | Length of cutting area.
**diameter** | ```<real>``` | Diameter at base of cutting area.
**nose_diameter** | ```<real>``` | Diameter at tip of cutting area.
**flutes** | ```<integer>``` | Number of flutes.
**lead_angle** | ```<real>``` | Flute lead angle.
**max_doc** | ```<real>``` | Maximum depth of cut
**max_woc** | ```<real>``` | Maximum width of cut
**max_rpm** | ```<real>``` | Maximum rotational speed
**max_feed** | ```<real>``` | Maximum feed rate

## Copy a tool
```none
PUT /users/{user}/tools/{tool}
PUT /users/{user}/tools/{tool}/children/{tool}
```

### Parameters
Name | Type | Description
:--|--|--
**ref** | ```<string>``` | A tool reference:```{user}/{tool}```.

## Rename a tool
```none
PUT /users/{user}/tools/{tool}
PUT /users/{user}/tools/{tool}/children/{tool}
```

### Parameters
Name | Type | Description
:--|--|--
**name** | ```<name>``` | New tool name.


## Delete a tool
```none
DELETE /users/{user}/tools/{tool}
DELETE /users/{user}/tools/{tool}/children/{tool}
```

# Search

[Pagination](#pagination) parameters apply to all search operations.

## Result Model
```coffeescript
<result> = {
  url: <url>
  result: <profile> | <project> | <machine> | <tool>
  offset: <string>
}
```

## Search for projects
```none
GET /search/projects
```

### Parameters
Name | Type | Description
:--|--|--
**query** | ```<string>``` | Search string.
**license** | ```<string>``` | Restrict to specified license.
**tags** | ```<string>``` | Restrict to specified tags.
**owner** | ```<name>``` | Restrict to specified owner.
**order_by** | ```<string>``` | ```stars```, ```creation```, ```modified```

## Search for users
```none
GET /search/users
```
Name | Type | Description
:--|--|--
**query** | ```<string>``` | Search string.
**order_by** | ```<string>``` | ```followers```, ```joined```

## Search for machines
```none
GET /search/machines
```
Name | Type | Description
:--|--|--
**query** | ```<string>``` | Search string.


## Search for tools
```none
GET /search/tools
```
Name | Type | Description
:--|--|--
**query** | ```<string>``` | Search string.

