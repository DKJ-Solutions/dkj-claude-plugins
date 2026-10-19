import { useState } from 'react'
import { Button, FilterChips, SegmentedChoice } from '../../components/Button'
import { Card, CardBody } from '../../components/Card'
import { FooterNote, GroupHeading } from '../../components/Content'
import { Prose } from '../../components/Prose'
import { Message, TitleTag } from '../../components/Feedback'
import { Checkbox, Stepper, TextField } from '../../components/Field'
import { PageHeader } from '../../components/Navigation'

type View = 'list' | 'recipe'

type Ingredient = { name: string; amount: number; unit: string; department: string }

type Recipe = {
  id: string
  title: string
  minutes: number
  tags: readonly string[]
  portions: number
  ingredients: readonly Ingredient[]
  method: readonly string[]
  source: string
}

/** Placeholder recipes: invented dishes, amounts and steps; nothing copied from a real collection. */
const RECIPES: readonly Recipe[] = [
  {
    id: 'r1',
    title: 'Example pasta bake',
    minutes: 35,
    tags: ['pasta', 'oven'],
    portions: 4,
    ingredients: [
      { name: 'Example pasta', amount: 300, unit: 'g', department: 'Dry goods' },
      { name: 'Tomato sauce', amount: 400, unit: 'ml', department: 'Dry goods' },
      { name: 'Example cheese', amount: 150, unit: 'g', department: 'Dairy' },
      { name: 'Cream', amount: 2, unit: 'dl', department: 'Dairy' },
      { name: 'Onion', amount: 1, unit: '', department: 'Vegetables' },
      { name: 'Example herbs', amount: 2, unit: 'tsp', department: 'Spices' },
    ],
    method: ['Boil the pasta until almost done.', 'Fry the onion and stir in the sauce and the cream.', 'Mix with the pasta, top with cheese and bake until golden.'],
    source: 'Invented example',
  },
  {
    id: 'r2',
    title: 'Example vegetable soup',
    minutes: 25,
    tags: ['soup', 'quick', 'vegetarian'],
    portions: 2,
    ingredients: [
      { name: 'Carrot', amount: 2, unit: '', department: 'Vegetables' },
      { name: 'Potato', amount: 3, unit: '', department: 'Vegetables' },
      { name: 'Stock', amount: 6, unit: 'dl', department: 'Dry goods' },
      { name: 'Example herbs', amount: 1, unit: 'tsp', department: 'Spices' },
    ],
    method: ['Chop the vegetables.', 'Simmer them in the stock until soft.', 'Season and serve.'],
    source: 'Invented example',
  },
  {
    id: 'r3',
    title: 'Example rice bowl',
    minutes: 20,
    tags: ['rice', 'quick', 'vegetarian'],
    portions: 2,
    ingredients: [
      { name: 'Example rice', amount: 200, unit: 'g', department: 'Dry goods' },
      { name: 'Egg', amount: 2, unit: '', department: 'Dairy' },
      { name: 'Spring onion', amount: 3, unit: '', department: 'Vegetables' },
      { name: 'Example sauce', amount: 2, unit: 'tbsp', department: 'Spices' },
    ],
    method: ['Cook the rice.', 'Fry the eggs.', 'Serve on the rice with chopped spring onion and the sauce.'],
    source: 'Invented example',
  },
  {
    id: 'r4',
    title: 'Example pancakes',
    minutes: 30,
    tags: ['sweet', 'breakfast'],
    portions: 4,
    ingredients: [
      { name: 'Flour', amount: 250, unit: 'g', department: 'Dry goods' },
      { name: 'Milk', amount: 5, unit: 'dl', department: 'Dairy' },
      { name: 'Egg', amount: 3, unit: '', department: 'Dairy' },
    ],
    method: ['Whisk the batter smooth and let it rest.', 'Fry thin pancakes in a hot pan.'],
    source: 'Invented example',
  },
]

const ALL_TAGS = [...new Set(RECIPES.flatMap((r) => r.tags))].sort()

const countText = (n: number, one: string, many: string) => `${n} ${n === 1 ? one : many}`

/** Scales a base amount to the chosen portions, to at most one decimal. */
function scaled(i: Ingredient, base: number, portions: number) {
  const n = Math.round(((i.amount * portions) / base) * 10) / 10
  return `${n}${i.unit ? ` ${i.unit}` : ''} ${i.name}`
}

function RecipeList({ list, onOpen }: { list: readonly string[]; onOpen: (id: string) => void }) {
  const [search, setSearch] = useState('')
  const [tags, setTags] = useState<string[]>([])
  const q = search.trim().toLowerCase()
  const visible = RECIPES.filter((r) => [r.title, ...r.tags, ...r.ingredients.map((i) => i.name)].some((x) => x.toLowerCase().includes(q)) && tags.every((t) => r.tags.includes(t)))
  return (
    <>
      <TextField label="Search" type="search" value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search recipes" />
      <div>
        <FilterChips showLabel label="Tags" options={ALL_TAGS.map((t) => ({ value: t, label: t }))} value={tags} onChange={setTags} />
      </div>
      {visible.length === 0 && <Message>No recipe found.</Message>}
      {visible.map((r) => (
        <Card key={r.id}>
          <CardBody>
            <strong>{r.title}</strong>
            <Message>{[`${r.minutes} min`, countText(r.ingredients.length, 'ingredient', 'ingredients'), ...r.tags].join(' · ')}</Message>
            <div className="dkj-preview-gap dkj-demo-row">
              {r.tags.map((t) => (
                <TitleTag key={t}>{t}</TitleTag>
              ))}
              <Button variant="outline" size="compact" onClick={() => onOpen(r.id)}>
                Open recipe{list.includes(r.id) ? ' (on the list)' : ''}
              </Button>
            </div>
          </CardBody>
        </Card>
      ))}
    </>
  )
}

function RecipePage({ recipe, onBack, onList, onToggleList }: { recipe: Recipe; onBack: () => void; onList: boolean; onToggleList: () => void }) {
  const [n, setN] = useState(recipe.portions)
  const [checked, setChecked] = useState<readonly string[]>([])
  const key = (i: Ingredient) => i.name
  const toggle = (k: string) => setChecked((c) => (c.includes(k) ? c.filter((x) => x !== k) : [...c, k]))
  const reset = () => setChecked([])
  const departments = [...new Set(recipe.ingredients.map((i) => i.department))]
  return (
    <>
      <div>
        <Button variant="outline" size="compact" onClick={onBack}>
          &larr; Recipes
        </Button>
      </div>
      <Message>{[`${recipe.minutes} min`, countText(recipe.ingredients.length, 'ingredient', 'ingredients'), ...recipe.tags].join(' · ')}</Message>
      <Button variant={onList ? 'outline' : 'primary'} aria-pressed={onList} onClick={onToggleList}>
        {onList ? 'On the shopping list' : 'Add to shopping list'}
      </Button>

      <Card variant="data">
        <CardBody>
          <GroupHeading level={2}>Portions</GroupHeading>
          <Stepper label="Portions" value={n} min={1} max={20} onChange={setN} />
        </CardBody>
      </Card>

      <Card variant="data">
        <CardBody>
          <GroupHeading level={2}>Ingredients</GroupHeading>
          <Button variant="outline" size="compact" onClick={reset}>
            Reset
          </Button>
          {departments.map((d) => (
            <div key={d} className="dkj-preview-gap">
              <GroupHeading level={3}>{d}</GroupHeading>
              {recipe.ingredients
                .filter((i) => i.department === d)
                .map((i) => (
                  <div key={key(i)} className={checked.includes(key(i)) ? 'dkj-preview-done' : undefined}>
                    <Checkbox label={scaled(i, recipe.portions, n)} checked={checked.includes(key(i))} onChange={() => toggle(key(i))} />
                  </div>
                ))}
            </div>
          ))}
        </CardBody>
      </Card>

      <Card variant="data">
        <CardBody>
          <GroupHeading level={2}>Method</GroupHeading>
          <Prose>
            <ol>
              {recipe.method.map((s) => (
                <li key={s}>{s}</li>
              ))}
            </ol>
          </Prose>
          <Message>Source: {recipe.source}</Message>
        </CardBody>
      </Card>
    </>
  )
}

/** A recreation of the two screens of dkj-recipes (the recipe list and a recipe page), with placeholder content. */
export function RecipesPreview() {
  const [view, setView] = useState<View>('list')
  const [openId, setOpenId] = useState(RECIPES[0].id)
  const [list, setList] = useState<readonly string[]>([])
  const recipe = RECIPES.find((r) => r.id === openId) ?? RECIPES[0]
  const toggleList = () => setList((l) => (l.includes(recipe.id) ? l.filter((x) => x !== recipe.id) : [...l, recipe.id]))
  return (
    <div className="dkj-preview-app dkj-preview-app--padded">
      <PageHeader title={view === 'list' ? 'Recipes' : recipe.title}>
        {view === 'list' && <Button variant="outline" size="compact">{`Shopping list (${list.length})`}</Button>}
        <SegmentedChoice
          label="Screen"
          layout="joined"
          value={view}
          onChange={setView}
          options={[
            { value: 'list', label: 'Recipes' },
            { value: 'recipe', label: 'Recipe' },
          ]}
        />
      </PageHeader>
      <div className="dkj-preview-column">
        {view === 'list' && (
          <RecipeList
            list={list}
            onOpen={(id) => {
              setOpenId(id)
              setView('recipe')
            }}
          />
        )}
        {view === 'recipe' && <RecipePage key={recipe.id} recipe={recipe} onBack={() => setView('list')} onList={list.includes(recipe.id)} onToggleList={toggleList} />}
        <FooterNote>A recreated preview; every recipe, amount and step is invented. The real app is an installable static site (PWA).</FooterNote>
      </div>
    </div>
  )
}
