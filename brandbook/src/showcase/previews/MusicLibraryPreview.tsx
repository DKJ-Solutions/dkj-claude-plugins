import { useState } from 'react'
import { Button, FilterChips, SegmentedChoice } from '../../components/Button'
import { Card, CardBody, CardHead, TintedPanel } from '../../components/Card'
import { BarChart, type BarDatum } from '../../components/Chart'
import { FooterNote, GroupHeading } from '../../components/Content'
import { Message, TitleTag } from '../../components/Feedback'
import { Checkbox, SelectField, TextField } from '../../components/Field'
import { Legend, LegendItem, StatTile, StatTiles } from '../../components/Metrics'
import { PageHeader } from '../../components/Navigation'
import { DataTable, type DataSort } from '../../components/Table'

type View = 'playlists' | 'dashboard' | 'tracks'

const ALL = 'All'
const COLOURS = [
  { value: 'Blue', label: 'Blue', color: 'var(--cat-1)' },
  { value: 'Orange', label: 'Orange', color: 'var(--cat-2)' },
  { value: 'Green', label: 'Green', color: 'var(--cat-3)' },
] as const
type Colour = (typeof COLOURS)[number]['value']
const DENSITIES = ['Low', 'Mid', 'High'].map((d) => ({ value: d, label: d }))
const BPM_TIERS = ['Slow', 'Medium', 'Fast'].map((b) => ({ value: b, label: b }))

type Playlist = {
  id: string
  world: string
  type: string
  bpm: string
  name: string
  colour: Colour
  mixId: string
  genre: string
  density: string
  tracks: number
  done: boolean
}

/** Placeholder playlists: invented names, worlds and ids; nothing from a real library. */
const PLAYLISTS: readonly Playlist[] = [
  { id: 'p1', world: 'World A', type: 'Set', bpm: 'Slow', name: 'Example playlist 1', colour: 'Blue', mixId: 'mix-001', genre: 'Genre one', density: 'Low', tracks: 42, done: true },
  { id: 'p2', world: 'World A', type: 'Set', bpm: 'Medium', name: 'Example playlist 2', colour: 'Orange', mixId: 'mix-002', genre: 'Genre two', density: 'Mid', tracks: 31, done: false },
  { id: 'p3', world: 'World B', type: 'Archive', bpm: 'Fast', name: 'Example playlist 3', colour: 'Green', mixId: '', genre: 'Genre one', density: 'High', tracks: 58, done: false },
  { id: 'p4', world: 'World B', type: 'Set', bpm: 'Medium', name: 'Example playlist 4', colour: 'Blue', mixId: 'mix-004', genre: 'Genre three', density: 'Mid', tracks: 24, done: true },
  { id: 'p5', world: 'World C', type: 'Archive', bpm: 'Slow', name: 'Example playlist 5', colour: 'Orange', mixId: '', genre: 'Genre two', density: 'Low', tracks: 17, done: false },
  { id: 'p6', world: 'World C', type: 'Set', bpm: 'Fast', name: 'Example playlist 6', colour: 'Green', mixId: 'mix-006', genre: 'Genre three', density: 'High', tracks: 66, done: false },
]

const WORLDS = [
  { emoji: '🎧', label: 'World A', count: 2 },
  { emoji: '🌊', label: 'World B', count: 2 },
  { emoji: '🌙', label: 'World C', count: 2 },
] as const

const yesNo = (b: boolean) => (b ? 'Yes' : 'No')

/** Sorts rows by a column key, numbers as numbers and everything else as text. */
function sortedBy<T extends Record<string, unknown>>(rows: readonly T[], sort: DataSort): T[] {
  const dir = sort.direction === 'ascending' ? 1 : -1
  return [...rows].sort((a, b) => {
    const x = a[sort.key]
    const y = b[sort.key]
    return (typeof x === 'number' && typeof y === 'number' ? x - y : String(x).localeCompare(String(y))) * dir
  })
}

function useSort(initial: DataSort) {
  const [sort, setSort] = useState<DataSort>(initial)
  const onSort = (key: string) => setSort((s) => ({ key, direction: s.key === key && s.direction === 'ascending' ? 'descending' : 'ascending' }))
  return [sort, onSort] as const
}

function PlaylistManager() {
  const [connected, setConnected] = useState(true)
  const [search, setSearch] = useState('')
  const [colours, setColours] = useState<Colour[]>([])
  const [densities, setDensities] = useState<string[]>([])
  const [bpmTiers, setBpmTiers] = useState<string[]>([])
  const [type, setType] = useState(ALL)
  const [genre, setGenre] = useState(ALL)
  const [idFilled, setIdFilled] = useState<'all' | 'yes' | 'no'>('all')
  const [done, setDone] = useState<Readonly<Record<string, boolean>>>(() => Object.fromEntries(PLAYLISTS.map((p) => [p.id, p.done])))
  const [sort, onSort] = useSort({ key: 'name', direction: 'ascending' })

  const clear = () => {
    setSearch('')
    setColours([])
    setDensities([])
    setBpmTiers([])
    setType(ALL)
    setGenre(ALL)
    setIdFilled('all')
  }

  const visible = PLAYLISTS.filter(
    (p) =>
      p.name.toLowerCase().includes(search.trim().toLowerCase()) &&
      (colours.length === 0 || colours.includes(p.colour)) &&
      (densities.length === 0 || densities.includes(p.density)) &&
      (bpmTiers.length === 0 || bpmTiers.includes(p.bpm)) &&
      (type === ALL || p.type === type) &&
      (genre === ALL || p.genre === genre) &&
      (idFilled === 'all' || (idFilled === 'yes') === (p.mixId !== '')),
  )
  const artists = 14

  return (
    <>
      <TitleTag>Music library</TitleTag>
      <Message>Every playlist of the library in one place, sorted into worlds. Placeholder lede.</Message>

      <Card variant="data">
        <CardHead title="Connection" />
        <CardBody>
          <Message>{connected ? 'Connected to the example music service.' : 'Not connected.'}</Message>
          <div className="dkj-preview-gap">
            <Button variant="outline" onClick={() => setConnected((c) => !c)}>
              {connected ? 'Disconnect' : 'Connect'}
            </Button>{' '}
            <Button variant="primary" block disabled={!connected}>
              Sync playlists
            </Button>
          </div>
        </CardBody>
      </Card>

      <Card variant="data">
        <CardHead title="Worlds" subtitle={`${PLAYLISTS.length} playlists in total`} />
        <CardBody>
          <StatTiles>
            {WORLDS.map((w) => (
              <StatTile key={w.label} label={`${w.emoji} ${w.label}`} value={w.count} />
            ))}
          </StatTiles>
        </CardBody>
      </Card>

      <StatTiles>
        <StatTile label="Playlists" value={PLAYLISTS.length} />
        <StatTile label="Artists" value={artists} />
        <StatTile label="With ID" value={PLAYLISTS.filter((p) => p.mixId).length} />
        <StatTile label="In the DJ world" value={3} />
        <StatTile label="Sync" value="✓ Up to date" tone="positive" />
      </StatTiles>

      <Card variant="data">
        <CardHead title="Playlists" subtitle={`${visible.length} of ${PLAYLISTS.length} shown`} />
        <CardBody>
          <div className="dkj-preview-tiles">
            <TextField label="Search" type="search" value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Playlist name" />
            <SelectField label="Type" options={[ALL, 'Set', 'Archive']} value={type} onChange={(e) => setType(e.target.value)} />
            <SelectField label="Genre" options={[ALL, 'Genre one', 'Genre two', 'Genre three']} value={genre} onChange={(e) => setGenre(e.target.value)} />
          </div>
          <div className="dkj-preview-gap">
            <FilterChips showLabel label="Colour" options={COLOURS} value={colours} onChange={setColours} />
          </div>
          <div className="dkj-preview-gap">
            <FilterChips showLabel label="Density" options={DENSITIES} value={densities} onChange={setDensities} />
          </div>
          <div className="dkj-preview-gap">
            <FilterChips showLabel label="BPM tier" options={BPM_TIERS} value={bpmTiers} onChange={setBpmTiers} />
          </div>
          <div className="dkj-preview-gap">
            <SegmentedChoice
              label="ID filled"
              layout="joined"
              value={idFilled}
              onChange={setIdFilled}
              options={[
                { value: 'all', label: 'ID: any' },
                { value: 'yes', label: 'ID filled' },
                { value: 'no', label: 'No ID' },
              ]}
            />{' '}
            <Button variant="outline" size="compact" onClick={clear}>
              Clear filters
            </Button>
          </div>
          <div className="dkj-preview-gap">
            <DataTable
              label="Playlists"
              sort={sort}
              onSort={onSort}
              columns={[
                { key: 'world', label: 'World', sortable: true },
                { key: 'type', label: 'Type', sortable: true },
                { key: 'bpm', label: 'BPM tier', sortable: true },
                { key: 'name', label: 'Name', sortable: true },
                { key: 'colour', label: 'Colour', sortable: true },
                { key: 'mixId', label: 'Mix ID', sortable: true },
                { key: 'genre', label: 'Genre', sortable: true },
                { key: 'density', label: 'Density', sortable: true },
                { key: 'tracks', label: 'Tracks', sortable: true },
                { key: 'done', label: 'Done' },
              ]}
              rows={sortedBy(visible, sort).map((p) => ({
                id: p.id,
                cells: {
                  world: p.world,
                  type: p.type,
                  bpm: p.bpm,
                  name: p.name,
                  colour: p.colour,
                  mixId: p.mixId || '—',
                  genre: p.genre,
                  density: p.density,
                  tracks: p.tracks,
                  done: (
                    <Checkbox
                      label={yesNo(done[p.id])}
                      aria-label={`Done: ${p.name}`}
                      checked={done[p.id]}
                      onChange={(e) => setDone((d) => ({ ...d, [p.id]: e.target.checked }))}
                    />
                  ),
                },
              }))}
              empty="No playlists match these filters"
            />
          </div>
        </CardBody>
      </Card>
    </>
  )
}

const DUPLICATES = [
  { id: 'd1', track: 'Example track A', count: 3, where: 'Example playlist 1, 3, 6' },
  { id: 'd2', track: 'Example track B', count: 2, where: 'Example playlist 2, 4' },
  { id: 'd3', track: 'Example track C', count: 2, where: 'Example playlist 5, 6' },
]

const TOP_ARTISTS: readonly BarDatum[] = [
  { key: 'a1', label: '1. Example artist one', short: '1. Artist one', value: 34 },
  { key: 'a2', label: '2. Example artist two', short: '2. Artist two', value: 27 },
  { key: 'a3', label: '3. Example artist three', short: '3. Artist three', value: 19 },
  { key: 'a4', label: '4. Example artist four', short: '4. Artist four', value: 12 },
  { key: 'a5', label: '5. Example artist five', short: '5. Artist five', value: 8 },
]

const COLOUR_COUNTS: readonly BarDatum[] = [
  { key: 'c1', label: 'Blue', value: 2, series: 1 },
  { key: 'c2', label: 'Orange', value: 2, series: 2 },
  { key: 'c3', label: 'Green', value: 2, series: 3 },
]

const tracksText = (n: number) => `${n} tracks`

function DataDashboard() {
  return (
    <>
      <Card variant="data">
        <CardHead title="Duplicates" subtitle="Tracks that sit in more than one playlist" />
        <CardBody>
          <GroupHeading level={3} count={DUPLICATES.length}>Duplicate tracks</GroupHeading>
          <DataTable
            label="Duplicate tracks"
            columns={[
              { key: 'track', label: 'Track' },
              { key: 'count', label: 'Times' },
              { key: 'where', label: 'Playlists' },
            ]}
            rows={DUPLICATES.map((d) => ({ id: d.id, cells: { track: d.track, count: `${d.count}×`, where: d.where } }))}
            empty="No duplicates"
          />
        </CardBody>
      </Card>

      <Card variant="data">
        <CardHead title="Top artists" subtitle="Ranked by number of tracks" />
        <CardBody>
          <BarChart colorBy="series" label="Top artists" data={TOP_ARTISTS.map((d) => ({ ...d, series: 1 as const }))} format={tracksText} itemHeading="Artist" valueHeading="Tracks" />
        </CardBody>
      </Card>

      <Card variant="data">
        <CardHead title="Distributions" />
        <CardBody>
          <GroupHeading level={3}>Worlds</GroupHeading>
          <StatTiles>
            {WORLDS.map((w) => (
              <StatTile key={w.label} label={`${w.emoji} ${w.label}`} value={w.count} />
            ))}
          </StatTiles>
          <div className="dkj-preview-gap">
            <GroupHeading level={3}>Colours</GroupHeading>
            <Legend>
              {COLOUR_COUNTS.map((c) => (
                <LegendItem key={c.key} color={c.series === 1 ? 'cat-1' : c.series === 2 ? 'cat-2' : 'cat-3'}>
                  {c.label}
                </LegendItem>
              ))}
            </Legend>
            <BarChart colorBy="series" label="Playlists per colour" data={COLOUR_COUNTS} format={(n) => `${n} playlists`} itemHeading="Colour" valueHeading="Playlists" />
          </div>
          <div className="dkj-preview-gap">
            <GroupHeading level={3}>BPM tiers</GroupHeading>
            <StatTiles>
              <StatTile label="Slow" value={2} />
              <StatTile label="Medium" value={2} />
              <StatTile label="Fast" value={2} />
            </StatTiles>
          </div>
        </CardBody>
      </Card>
    </>
  )
}

type Track = { id: string; title: string; artist: string; bpm: number; genre: string; album: string; group: string }

/** Placeholder tracks: invented titles, artists and albums. */
const TRACKS: readonly Track[] = [
  { id: 't1', title: 'Example track A', artist: 'Example artist one', bpm: 96, genre: 'Genre one', album: 'Example album 1', group: 'Group X' },
  { id: 't2', title: 'Example track B', artist: 'Example artist two', bpm: 118, genre: 'Genre two', album: 'Example album 2', group: 'Group Y' },
  { id: 't3', title: 'Example track C', artist: 'Example artist one', bpm: 128, genre: 'Genre one', album: 'Example album 1', group: 'Group X' },
  { id: 't4', title: 'Example track D', artist: 'Example artist three', bpm: 140, genre: 'Genre three', album: 'Example album 3', group: 'Group Y' },
]

function TrackRegister() {
  const [search, setSearch] = useState('')
  const [bpm, setBpm] = useState(ALL)
  const [genre, setGenre] = useState(ALL)
  const [album, setAlbum] = useState(ALL)
  const [group, setGroup] = useState(ALL)
  const [sort, onSort] = useSort({ key: 'title', direction: 'ascending' })
  const bpmBand = (n: number) => (n < 110 ? 'Under 110' : n < 130 ? '110 to 130' : 'Over 130')
  const q = search.trim().toLowerCase()
  const visible = TRACKS.filter(
    (t) =>
      `${t.title} ${t.artist}`.toLowerCase().includes(q) &&
      (bpm === ALL || bpmBand(t.bpm) === bpm) &&
      (genre === ALL || t.genre === genre) &&
      (album === ALL || t.album === album) &&
      (group === ALL || t.group === group),
  )
  const clear = () => {
    setSearch('')
    setBpm(ALL)
    setGenre(ALL)
    setAlbum(ALL)
    setGroup(ALL)
  }
  return (
    <>
      <StatTiles>
        <StatTile label="Tracks" value={TRACKS.length} />
        <StatTile label="Shown" value={visible.length} />
        <StatTile label="Artists" value={new Set(TRACKS.map((t) => t.artist)).size} />
        <StatTile label="Albums" value={new Set(TRACKS.map((t) => t.album)).size} />
      </StatTiles>

      <Card variant="data">
        <CardHead title="Filters" />
        <CardBody>
          <fieldset>
            <legend>Filter the tracks</legend>
            <div className="dkj-preview-tiles">
            <TextField label="Search" type="search" value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Title or artist" />
            <SelectField label="BPM" options={[ALL, 'Under 110', '110 to 130', 'Over 130']} value={bpm} onChange={(e) => setBpm(e.target.value)} />
            <SelectField label="Genre" options={[ALL, 'Genre one', 'Genre two', 'Genre three']} value={genre} onChange={(e) => setGenre(e.target.value)} />
            <SelectField label="Album" options={[ALL, 'Example album 1', 'Example album 2', 'Example album 3']} value={album} onChange={(e) => setAlbum(e.target.value)} />
            <SelectField label="Group" options={[ALL, 'Group X', 'Group Y']} value={group} onChange={(e) => setGroup(e.target.value)} />
            </div>
          </fieldset>
          <div className="dkj-preview-gap">
            <Button variant="outline" size="compact" onClick={clear}>
              Clear filters
            </Button>
          </div>
        </CardBody>
      </Card>

      <Card variant="data">
        <CardHead title="Tracks" />
        <CardBody>
          <DataTable
            label="Tracks"
            sort={sort}
            onSort={onSort}
            columns={[
              { key: 'title', label: 'Title', sortable: true },
              { key: 'artist', label: 'Artist', sortable: true },
              { key: 'bpm', label: 'BPM', sortable: true },
              { key: 'genre', label: 'Genre', sortable: true },
              { key: 'album', label: 'Album', sortable: true },
              { key: 'group', label: 'Group', sortable: true },
            ]}
            rows={sortedBy(visible, sort).map((t) => ({ id: t.id, cells: { title: t.title, artist: t.artist, bpm: t.bpm, genre: t.genre, album: t.album, group: t.group } }))}
            empty="No tracks match these filters"
          />
          <div className="dkj-preview-gap">
            <TintedPanel>
              <strong>Player</strong>
              <Message>A placeholder strip: the real page embeds the music service player here, below the table.</Message>
            </TintedPanel>
          </div>
        </CardBody>
      </Card>
    </>
  )
}

const TITLES: Record<View, string> = { playlists: 'Playlist manager', dashboard: 'Data dashboard', tracks: 'Track register' }

/** A recreation of the three screens of dkj-music-library (playlist manager, data dashboard, track register), with placeholder content. */
export function MusicLibraryPreview() {
  const [view, setView] = useState<View>('playlists')
  return (
    <div className="dkj-preview-app dkj-preview-app--padded">
      <PageHeader title={TITLES[view]}>
        <SegmentedChoice
          label="Screen"
          layout="joined"
          value={view}
          onChange={setView}
          options={[
            { value: 'playlists', label: 'Playlists' },
            { value: 'dashboard', label: 'Dashboard' },
            { value: 'tracks', label: 'Tracks' },
          ]}
        />
      </PageHeader>
      <div className="dkj-preview-column dkj-preview-column--wide">
        {view === 'playlists' && <PlaylistManager />}
        {view === 'dashboard' && <DataDashboard />}
        {view === 'tracks' && <TrackRegister />}
        <FooterNote>A recreated preview; every playlist, artist and track is invented. The real app is a local Next.js app with no deployment, so it has no live link.</FooterNote>
      </div>
    </div>
  )
}
