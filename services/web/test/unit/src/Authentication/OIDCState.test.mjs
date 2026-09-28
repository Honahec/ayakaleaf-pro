import crypto from 'node:crypto'
import { promisify } from 'node:util'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import sinon from 'sinon'
import SessionStore from 'passport-openidconnect/lib/state/session.js'

const key = 'openidconnect:example.test'
const randomBytes = Buffer.from('fbff'.repeat(9), 'hex')

describe('OIDC authorization state', function () {
  let randomStub
  let store
  let req

  beforeEach(function () {
    randomStub = sinon.stub(crypto, 'randomBytes').returns(randomBytes)
    store = new SessionStore({ key })
    req = { session: {} }
  })

  afterEach(function () {
    randomStub.restore()
  })

  it('survives an authorization server interpolating state into a callback URL', async function () {
    const handle = await promisify(store.store.bind(store))(req, {}, null, {})
    const returnedState = new URL(
      `https://example.test/oidc/login/callback?code=code&state=${handle}`
    ).searchParams.get('state')

    expect(returnedState).to.equal(handle)
    expect(Buffer.from(handle, 'base64url')).to.deep.equal(randomBytes)
    const context = await promisify(store.verify.bind(store))(req, returnedState)
    expect(context).to.be.an('object')
    expect(await promisify(store.verify.bind(store))(req, returnedState)).to.equal(false)
  })

  it('rejects a state that belongs to another session', async function () {
    const handle = await promisify(store.store.bind(store))(req, {}, null, {})
    const otherRequest = { session: {} }
    expect(await promisify(store.verify.bind(store))(otherRequest, handle)).to.equal(false)
  })

  it('rejects an altered state even when the session cookie is valid', async function () {
    const handle = await promisify(store.store.bind(store))(req, {}, null, {})
    expect(await promisify(store.verify.bind(store))(req, `${handle}x`)).to.equal(false)
  })
})
