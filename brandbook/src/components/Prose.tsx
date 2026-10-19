import type { ReactNode } from 'react'
import { cx } from './cx'
import './prose.css'

/**
 * Prose -- a rendered long-form body (markdown output): headings, paragraphs, lists with task-list checkboxes,
 * a small table, inline and block code, a blockquote, links and a rule. A styling wrapper: the children are plain
 * elements (or the output of a markdown renderer), and no class is needed on any of them.
 * size: "sm" for a body inside a card or tile. measure: "none" fills the container instead of the 70ch reading width.
 * A scrolling `pre` or `table` needs tabIndex={0} so the keyboard can reach it.
 */
export function Prose({
  size = 'base',
  measure = 'text',
  className,
  children,
}: {
  size?: 'base' | 'sm'
  measure?: 'text' | 'none'
  className?: string
  children: ReactNode
}) {
  return <div className={cx('dkj-prose', size === 'sm' && 'dkj-prose--sm', measure === 'none' && 'dkj-prose--fill', className)}>{children}</div>
}
