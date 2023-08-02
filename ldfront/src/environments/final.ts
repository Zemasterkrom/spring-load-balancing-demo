type Endpoints = {
  [key: string]: string
}

export const endpoints:Endpoints = {
  allVideoGames: '/video-games/all',
  oneVideoGame: '/video-games/:id',
  addVideoGame: '/video-games/add',
  updateVideoGame: '/video-games/modify/:id',
  deleteVideoGame: '/video-games/delete/:id'
};