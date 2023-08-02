/**
 * Représente les données pouvant être acceptées pour un jeu vidéo (modèle utilisé dans les composants pour le typage)
 */
export type VideoGame = {
  id?: any,
  name: string,
  editor: string,
  description?: string,
  releasedDate: string,
  error?: string
}