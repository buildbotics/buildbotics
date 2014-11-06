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
 3. As JSON encoded data with ```Content-Type: application/json```.

[rfc3986-3.4]: http://tools.ietf.org/html/rfc3986#section-3.4

URL parameters are specified using curly braces.  For example:

```none
PUT /users/{name}/follow
```

In the above case ```{name}``` is a URL parameter.

For POST, PUT and DELETE request parameters not included in the URL path
should be encoded as JSON.


## Types
This section describes how data types are defined in this document.

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

### Inheritance
Data model inheritance is denoted as follows:
```coffeescript
<child>(<parent>) = {
  # Child property definitions here
}
```

Meaning the ```<child>``` model being defined, inherits all the properties
of ```<parent>``` model.

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

### References
```none
<ref> = <name>/<name>
```

A ```<ref>``` references a thing as owner name slash thing name.
For example, ```jimmy/fun_with_lasers```.


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

### Error Codes

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

## Authorization
Various API calls require different levels of authorization.  Authorization is
handled through the badge system and ownership.  For example, adding a new
license type might require the ```admin``` badge whereas editing a project
would require that either the user is the owner or has a badge sufficient to
override the ownership requirement.

In case a user attempts an operation for which they are not authorized,
a ```403 Forbidden``` or possibly ```404 Not Found``` HTTP response code will
be returned.

## Pagination
Request which return multiple items are paginated.  By default 20 items are
returned per call.  Each item is supplied with an ```offset``` key which
tells where it is in the stream.

### Parameters
Name | Type | Description
:--|--|--
**limit** | ```<integer>``` (1,100) | **Default 30**. Items per page.
**next** | ```<string>``` | Key of the item just before the requested page.
**prev** | ```<string>``` | Key of the item just after the requested page.

Either **next** or **prev** may be provided but not both.  Both parameters
should be copied from the ```<owner>/<name>``` of a previous request.

## Rate Limiting
Rate limits are as follows:

User | Max Requests in <br/> Past 5 Minutes
:--|--
Unauthenticated | 50
Authenticated   | 200

If you exceed the rate limit ```503 Service Unavailable``` will be returned.

# Authenticate

## Login
```none
GET /auth/{provider}
```
Where ```{provider}``` is one of:

 - ```google```
 - ```facebook```
 - ```twitter```
 - ```github```

## Login Callback
```none
GET /auth/{provider}/callback
```

## Logout
```none
GET /auth/logout
```

## Get Active User Profile
```none
GET /auth/user
```

### Response
```none
<profile>
```
or
```none
null
```

# Users
## Profile Model
User profiles are defined as follows:

```coffeescript
<profile> = {
  owner: <name>
  joined: <date>
  fullname: <string> (0,120)
  location: <string> (0,255)
  avatar: <url>
  bio: <markdown>
  url: <url>
  followers: <integer>
  following: <integer>
  stars: <integer>
  points: <integer>
  badges: <integer>
}
```

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
  followers: 2,
  following: 2,
  stars: 10,
  points: 10305,
  badges: 1
}
```

## Update user profile
```none
PUT /users/{name}
```

### Parameters
Name | Type | Description
:--|--|--
**avatar** | ```<url>``` | URL to user's avatar.
**bio** | ```<markdown>``` | User's public biography.
**url** | ```<url>``` | Link to user's home page.
**disabled** | ```<bool>``` | Disable the account.

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

## List who a user is following
```none
GET /users/{name}/following
```

## List user followers
```none
GET /users/{name}/followers
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
DELETE /users/{name}/follow
```

### Example
```
DELETE /users/johndoe/follow HTTP/1.1
```

```
Status: 200 OK
```

## List user stars
```none
GET /users/{user}/stars
```

### Response
```none
{
  projects: [<ref>...]
  machines: [<ref>...]
  tools: [<ref>...]
}
```

A list of projects the user has starred.

## List user badges
```none
GET /users/{user}/badges
```

## Grant a badge
```none
PUT /users/{user}/badges/{badge}
```

## Revoke a badge
```none
DELETE /users/{user}/badges/{badge}
```

### Parameters
Name | Type | Description
:--|--|--
**reason**  | ```<markdown>``` | The reason the badge was revoked.


# Settings
## Settings Model
```coffeescript
<settings> = {
  accounts: [<account>...]
  email: [<email>...] (0,8)
  notifications: <notifications>
}
```
```coffeescript
<account> = {
  type: <string>  # google, twitter, facebook, github
  id: <string>
  primary: <bool>
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

## Associate an account
```none
PUT /accounts/{type}
```

Only one account of each type can be associated at a time.

### Parameters
Name | Type | Description
:--|--|--
**id**  | ```<string>``` | Account ID
**primary** | ```<bool>``` | Is the primary account?

## Disassociate an account
```none
DELETE /accounts/{type}
```

Must not be the primary account.

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
    <td>**project_duplicated**</td><td>```<bool>```</td>
    <td>When a project is duplicated.</td>
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

# Things
a ```<thing>``` is an abstract model from
which ```<project>```, ```<machine>``` and ```<tool>``` inherit.

## Thing Model
```coffeescript
<thing> = {
  name: <name>
  owner: <name>
  creation: <date>
  modified: <date>
  parent: <ref>
  published: <bool>
  url: <url>
  license: <string> (2,120)
  brief: <markdown> (0,200)
  description: <markdown>
  comments: <integer>
  stars: <integer>
  tags: [<tag>...] (0,64)
  duplications: <integer>
  files: [<file>..] (0,64)
}
```

## Get a list of things
```none
GET /users/{user}/projects
GET /users/{user}/machines
GET /users/{user}/tools
GET /users/{user}/tools/{tool}/children
```

See [Search](#search).

## Create or update a thing
```none
PUT /users/{user}/projects/{project}
PUT /users/{user}/machines/{machine}
PUT /users/{user}/tools/{tool}
PUT /users/{user}/tools/{tool}/children/{tool}
```

### Parameters
Name | Type | Description
:--|--|--
**url** | ```<url>``` | A URL to more information about the thing.
**license** | ```<string>``` | One of the available license names.
**published** | ```<bool>``` | True to publish the thing publicly.
**description** | ```<markdown>``` | The thing description.

## Get a thing
```none
GET /users/{user}/projects/{project}
GET /users/{user}/machines/{machine}
GET /users/{user}/tools/{tool}
GET /users/{user}/tools/{tool}/children/{tool}
```

## Rename a thing
```none
PUT /users/{user}/projects/{project}
PUT /users/{user}/machines/{machine}
PUT /users/{user}/tools/{tool}
PUT /users/{user}/tools/{tool}/children/{tool}
```

### Parameters
Name | Type | Description
:--|--|--
**name** | ```<name>``` | The new thing name.

## Duplicate a thing
```none
PUT /users/{user}/projects/{project}
PUT /users/{user}/machines/{machine}
PUT /users/{user}/tools/{tool}
```

### Parameters
Name | Type | Description
:--|--|--
**ref** | ```<ref>``` | A reference to the parent owner and thing.

## Delete a thing
```none
DELETE /users/{user}/projects/{project}
DELETE /users/{user}/machines/{machine}
DELETE /users/{user}/tools/{tool}
DELETE /users/{user}/tools/{tool}/children/{tool}
```

## List thing stars
```none
GET /users/{user}/projects/{project}/stars
GET /users/{user}/machines/{machine}/stars
GET /users/{user}/tools/{tool}/stars
```

### Response
```none
[<name>...]
```
A list of users who have starred this thing.

## Star a thing
```none
PUT /users/{user}/projects/{project}/star
PUT /users/{user}/machines/{machine}/star
PUT /users/{user}/tools/{tool}/star
```

## Unstar a thing
```none
DELETE /users/{user}/projects/{project}/star
DELETE /users/{user}/machines/{machine}/star
DELETE /users/{user}/tools/{tool}/star
```

## Tag a thing
```none
PUT /users/{user}/projects/{project}/tags/{tag}
PUT /users/{user}/machines/{machine}/tags/{tag}
PUT /users/{user}/tools/{tool}/tags/{tag}
```

## Untag a thing
```none
DELETE /users/{user}/projects/{project}/tags/{tag}
DELETE /users/{user}/machines/{machine}/tags/{tag}
DELETE /users/{user}/tools/{tool}/tags/{tag}
```

# Projects
## Project Model
Inherits from the [thing](#things) abstract model.

```coffeescript
<project>(<thing>) = {
  machine: <ref>
  tools: {<integer>: <ref>...] (0,64)
  workpiece: <workpiece>
  steps: [<step>...] (0,64)
}
```
```coffeescript
<workpiece> = {
  material: <image>
  dimensions: <vector>
  offset: <vector>
}
<vector> = {
  x: <real>
  y: <real>
  z: <real>
}
```

# Steps
## Step Model
```coffeescript
<step> = {
  name: <name>
  brief: <markdown> (0,200)
  description: <markdown>
  comments: <integer>
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


# Machines
## Machine Model
Inherits from the [thing](#things) abstract model.

```coffeescript
<machine>(<thing>) = {
  type: <string>          # "cnc", "3d_printer", "laser", "plasma", "lathe"
  units: <string>         # "imperial" or "metric"
  rotation: <string>      # "degrees" or "radians"
  max_rpm: <real>         # Maximum rotational speed
  spin_up: <real>         # Rate of spin up in RPM/sec
  axes: [<axis>...] (1,9)
}
```
```coffeescript
<axis> = {
  name: <string>        # "x", "y", "z", "a", "b", "c", "u", "v" or "w"
  min: <real>           # in, mm, deg, radians
  max: <real>           # in, mm, deg, radians
  step: <real>          # in or mm
  rapid_feed: <real>    # in/sec or mm/sec
  cutting_feed: <real>  # in/sec or mm/sec
  ramp_up: <real>       # in/sec/sec or mm/sec/sec
  ramp_down: <real>     # in/sec/sec or mm/sec/sec
}
```

## Create or update a machine
```none
PUT /users/{user}/machines/{machine}
```

### Parameters
Name | Type | Description
:--|--|--
**type** | ```<string>``` | A machine type.
**units** | ```<string>``` | ```"imperial"``` or ```"metric"```.
**rotation** | ```<string>``` | ```"degrees"``` or ```"radians"```.
**max_rpm** | ```<real>``` | Maximum rotational speed.
**spin_up** | ```<real>``` | Rate of spin up in RPM/sec.

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
<tool>(<thing>) = {
  type: <string>         # "cylindrical", "conical", "ballnose",
                         # "spheroid" or "composite"
  units: <string>        # "imperial" or "metric"
  length: <real>         # Length of cutter
  diameter: <real>       # Diameter a base
  nose_diameter: <real>  # Diameter a tip
  flutes: <integer>      # Number of flutes
  flute_angle: <real>    # Rake angle of the flute
  lead_angle: <real>     # Angle between cutting edge & perpendicular plane
  max_doc: <real>        # Maximum depth of cut
  max_woc: <real>        # Maximum width of cut
  max_rpm: <real>        # Maximum rotational speed
  max_feed: <real>       # Maximum feed rate
  offset: <real>         # Composite tool children only
  children: [<tool>...]} # Composite tools only
}
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
**offset** | ```<real>``` | Maximum feed rate

# Comments
## Comment Model
```coffeescript
<comment> = {
  id: <integer>
  owner: <name>
  creation: <date>
  modified: <date>
  ref: <integer>   # A reference to a previous comment.
  text: <markdown>
  deleted: <bool>  # True if the comment was marked as deleted.
}
```

## List comments
```none
GET /users/{user}/projects/{project}/comments
GET /users/{user}/projects/{project}/steps/{step}/comments
GET /users/{user}/machines{machine}/comments
GET /users/{user}/tools/{tool}/comments
```

## Post a comment
```none
POST /users/{user}/projects/{project}/comments
POST /users/{user}/projects/{project}/steps/{step}/comments
POST /users/{user}/machines/{machine}/comments
POST /users/{user}/tools/{tool}/comments
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
PUT /users/{user}/machines/{machine}/comments/{comment}
PUT /users/{user}/tools/{tool}/comments/{comment}
```

### Parameters
Name | Type | Description
:--|--|--
**text** | ```<markdown>``` | The updated comment text.


## Mark a comment deleted
```none
DELETE /users/{user}/projects/{project}/comments/{comment}
DELETE /users/{user}/projects/{project}/steps/{step}/comments/{comment}
DELETE /users/{user}/machines/{machine}/comments/{comment}
DELETE /users/{user}/tools/{tool}/comments/{comment}
```

# Files
## File Model
```coffeescript
<file> = {
  name: <string> (1,256)
  type: <media_type>
  creation: <date>
  url: <url>
  downloads: <integer>
  caption: <string> (0,120)
  display: <bool>   # Images only
}
```

Actual file data is stored in Amazon S3 storage.  Requests to upload or change
the contents of a file will generate a signed S3 URL and authorization
parameters for file upload.

A file's ```<media_type>``` must match its file name extensions according to
[Amazon's File Extension to Mime Types table](http://goo.gl/2lOmj9).

## Upload or update a file
```none
PUT /users/{user}/projects/{project}/files/{file}
PUT /users/{user}/projects/{project}/steps/{step}/files/{file}
PUT /users/{user}/machines/{machine}/files/{file}
PUT /users/{user}/tools/{tool}/files/{file}
```

### Parameters
Name | Type | Description
:--|--|--
**caption** | ```<string> (0,120)``` | The file caption.
**display** | ```<bool>``` | **Images only***.  Display this image.
**position** | ```<integer>``` | The file position.

### Response
Name | Type | Description
:--|--|--
**url** | ```<url>``` | S3 file upload URL.
**key** | ```<string>``` | S3 key.
**acl** | ```<string>``` | S3 ACL.
**policy** | ```<string>``` | S3 policy.
**signature** | ```<string>``` | S3 signature.
**access** | ```<string>``` | S3 access key.

## Rename a file
```none
PUT /users/{user}/projects/{project}/files/{file}
PUT /users/{user}/projects/{project}/steps/{step}/files/{file}
PUT /users/{user}/machines/{machine}/files/{file}
PUT /users/{user}/tools/{tool}/files/{file}
```

Name | Type | Description
:--|--|--
**name** | ```<name>``` | The new file name.

## Delete a file
```none
DELETE /users/{user}/projects/{project}/files/{file}
DELETE /users/{user}/projects/{project}/steps/{step}/files/{file}
DELETE /users/{user}/machines/{machine}/files/{file}
DELETE /users/{user}/tools/{tool}/files/{file}
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
**grant** | A new badge was granted.
**revoke** | A badge was revoked.

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

## View events
```none
GET /users/{user}
GET /users/{user}/projects/{project}
GET /users/{user}/machines/{machine}
GET /users/{user}/tools/{tool}
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

# Badges
## Badge Model
```coffeescript
<badge> = {
  name: <name>
  points: <integer>
  description: <markdown>
}
```

## Get a list of badges
```none
GET /badges
```

## Create a new badge
```none
PUT /badges/{badge}
```

## Delete a badge
```none
DELETE /badges/{badge}
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

# Search
[Pagination](#pagination) parameters apply to all search operations.

## Search for users
```none
GET /users
```
Name | Type | Description
:--|--|--
**query** | ```<string>``` | Search string.
**order_by** | ```<string>``` | ```points```, ```followers```, ```joined```

## Search for things
```none
GET /projects
GET /machines
GET /tools
GET /users/{user}/projects
GET /users/{user}/machines
GET /users/{user}/tools
```

### Parameters
Name | Type | Description
:--|--|--
**query** | ```<string>``` | Search string.
**license** | ```<string>``` | Restrict to specified license.
**tags** | ```<string>``` | Restrict to specified tags.
**order_by** | ```<string>``` | ```stars```, ```creation```, ```modified```

